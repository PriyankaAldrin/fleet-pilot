using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Infrastructure.Ocr;
using FleetPilot.Api.Tests.Support;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;

namespace FleetPilot.Api.Tests.Unit;

public class ShiftServiceTests : IDisposable
{
    private readonly TestDb _t = new();

    public void Dispose() => _t.Dispose();

    private static StartShiftForm Start(int vehicleId, int km, int? ocr = null, double? conf = 0.95) => new()
    {
        ClientId = Guid.NewGuid(),
        VehicleId = vehicleId,
        StartKm = km,
        OcrKm = ocr ?? km,
        OcrConfidence = conf,
        Latitude = 25.2,
        Longitude = 55.27,
        Photo = TestDb.Photo(),
    };

    private static EndShiftForm End(int km, int? ocr = null) => new()
    {
        EndKm = km,
        OcrKm = ocr ?? km,
        OcrConfidence = 0.95,
        Photo = TestDb.Photo(),
    };

    [Fact]
    public async Task Start_and_end_a_clean_shift()
    {
        var d = _t.AddDriver();
        var v = _t.AddVehicle(odometer: 10_000);
        _t.CurrentUser.SignIn(d.User);

        var started = await _t.Shifts().StartAsync(Start(v.Id, 10_005));
        started.Status.Should().Be(ShiftStatus.Active);
        started.StartTime.Should().Be(_t.Clock.UtcNow);
        started.IsFlagged.Should().BeFalse();
        started.StartPhotoUrl.Should().Be($"/api/v1/shifts/{started.Id}/photos/start");

        _t.Clock.Advance(TimeSpan.FromHours(8.5));
        var ended = await _t.Shifts().EndAsync(started.Id, End(10_260));

        ended.Status.Should().Be(ShiftStatus.Completed);
        ended.DistanceKm.Should().Be(255);
        ended.DurationHours.Should().Be(8.5);
        ended.IsFlagged.Should().BeFalse();
        (await _t.Db.Vehicles.SingleAsync()).CurrentOdometer.Should().Be(10_260);
        _t.Storage.Files.Should().HaveCount(2);
    }

    [Fact]
    public async Task Edited_reading_is_flagged_for_review()
    {
        var d = _t.AddDriver();
        var v = _t.AddVehicle(odometer: 10_000);
        _t.CurrentUser.SignIn(d.User);

        var s = await _t.Shifts().StartAsync(Start(v.Id, 10_010, ocr: 16_010));

        s.IsFlagged.Should().BeTrue();
        s.KmManuallyEdited.Should().BeTrue();
        s.FlagReasons.Should().Contain(r => r.Contains("changed the reading"));
    }

    [Fact]
    public async Task Driver_cannot_have_two_active_shifts()
    {
        var d = _t.AddDriver();
        var v1 = _t.AddVehicle("A 1");
        var v2 = _t.AddVehicle("A 2");
        _t.CurrentUser.SignIn(d.User);
        await _t.Shifts().StartAsync(Start(v1.Id, 10_000));

        var act = () => _t.Shifts().StartAsync(Start(v2.Id, 10_000));

        await act.Should().ThrowAsync<ConflictException>().WithMessage("*already have an active shift*");
    }

    [Fact]
    public async Task Vehicle_cannot_be_in_two_active_shifts()
    {
        var d1 = _t.AddDriver("a@x.io");
        var d2 = _t.AddDriver("b@x.io");
        var v = _t.AddVehicle();
        _t.CurrentUser.SignIn(d1.User);
        await _t.Shifts().StartAsync(Start(v.Id, 10_000));

        _t.CurrentUser.SignIn(d2.User);
        var act = () => _t.Shifts().StartAsync(Start(v.Id, 10_000));

        await act.Should().ThrowAsync<ConflictException>().WithMessage("*already in use*");
    }

    [Fact]
    public async Task Database_index_blocks_a_second_active_shift_for_a_vehicle()
    {
        var d1 = _t.AddDriver("a@x.io");
        var d2 = _t.AddDriver("b@x.io");
        var v = _t.AddVehicle();
        _t.Db.Shifts.Add(new Shift { ClientId = Guid.NewGuid(), DriverId = d1.UserId, VehicleId = v.Id, Status = ShiftStatus.Active });
        _t.Db.Shifts.Add(new Shift { ClientId = Guid.NewGuid(), DriverId = d2.UserId, VehicleId = v.Id, Status = ShiftStatus.Active });

        var act = () => _t.Db.SaveChangesAsync();

        await act.Should().ThrowAsync<DbUpdateException>();
    }

    [Fact]
    public async Task End_km_below_start_km_is_rejected()
    {
        var d = _t.AddDriver();
        var v = _t.AddVehicle();
        _t.CurrentUser.SignIn(d.User);
        var s = await _t.Shifts().StartAsync(Start(v.Id, 10_000));

        var act = () => _t.Shifts().EndAsync(s.Id, End(9_999));

        await act.Should().ThrowAsync<BusinessRuleException>().WithMessage("*cannot be lower*");
    }

    [Fact]
    public async Task Unrealistic_distance_is_flagged()
    {
        var d = _t.AddDriver();
        var v = _t.AddVehicle();
        _t.CurrentUser.SignIn(d.User);
        var s = await _t.Shifts().StartAsync(Start(v.Id, 10_000));

        var ended = await _t.Shifts().EndAsync(s.Id, End(11_500));

        ended.IsFlagged.Should().BeTrue();
        ended.FlagReasons.Should().Contain(r => r.Contains("1000 km limit"));
    }

    [Fact]
    public async Task Server_ocr_disagreement_is_flagged()
    {
        var d = _t.AddDriver();
        var v = _t.AddVehicle();
        _t.CurrentUser.SignIn(d.User);
        _t.Ocr.Next = new OcrResult(19_000, 0.93, "19000");

        var s = await _t.Shifts().StartAsync(Start(v.Id, 10_000));

        s.StartKmServerOcr.Should().Be(19_000);
        s.FlagReasons.Should().Contain(r => r.Contains("server read 19000"));
    }

    [Fact]
    public async Task Repeated_start_with_same_client_id_returns_the_same_shift()
    {
        var d = _t.AddDriver();
        var v = _t.AddVehicle();
        _t.CurrentUser.SignIn(d.User);
        var form = Start(v.Id, 10_000);

        var first = await _t.Shifts().StartAsync(form);
        form.Photo = TestDb.Photo();
        var second = await _t.Shifts().StartAsync(form);

        second.Id.Should().Be(first.Id);
        (await _t.Db.Shifts.CountAsync()).Should().Be(1);
    }

    [Fact]
    public async Task Repeated_end_is_idempotent()
    {
        var d = _t.AddDriver();
        var v = _t.AddVehicle();
        _t.CurrentUser.SignIn(d.User);
        var s = await _t.Shifts().StartAsync(Start(v.Id, 10_000));
        await _t.Shifts().EndAsync(s.Id, End(10_100));

        var again = await _t.Shifts().EndAsync(s.Id, End(10_100));

        again.EndKm.Should().Be(10_100);
    }

    [Fact]
    public async Task Offline_timestamp_is_used_when_within_limits()
    {
        var d = _t.AddDriver();
        var v = _t.AddVehicle();
        _t.CurrentUser.SignIn(d.User);
        var form = Start(v.Id, 10_000);
        form.RecordedOffline = true;
        form.CapturedAt = _t.Clock.UtcNow.AddHours(-3);

        var s = await _t.Shifts().StartAsync(form);

        s.StartTime.Should().Be(_t.Clock.UtcNow.AddHours(-3));
        s.RecordedOffline.Should().BeTrue();
    }

    [Fact]
    public async Task Offline_timestamp_in_the_future_is_rejected()
    {
        var d = _t.AddDriver();
        var v = _t.AddVehicle();
        _t.CurrentUser.SignIn(d.User);
        var form = Start(v.Id, 10_000);
        form.RecordedOffline = true;
        form.CapturedAt = _t.Clock.UtcNow.AddHours(1);

        var act = () => _t.Shifts().StartAsync(form);

        await act.Should().ThrowAsync<BusinessRuleException>();
    }

    [Fact]
    public async Task Driver_only_sees_own_shifts()
    {
        var d1 = _t.AddDriver("a@x.io");
        var d2 = _t.AddDriver("b@x.io");
        var v1 = _t.AddVehicle("A 1");
        var v2 = _t.AddVehicle("A 2");
        _t.CurrentUser.SignIn(d1.User);
        await _t.Shifts().StartAsync(Start(v1.Id, 10_000));
        _t.CurrentUser.SignIn(d2.User);
        var other = await _t.Shifts().StartAsync(Start(v2.Id, 10_000));

        _t.CurrentUser.SignIn(d1.User);
        var list = await _t.Shifts().ListAsync(new ShiftListQuery { DriverId = d2.UserId });
        var act = () => _t.Shifts().GetAsync(other.Id);

        list.Items.Should().OnlyContain(s => s.DriverId == d1.UserId);
        await act.Should().ThrowAsync<NotFoundException>();
    }

    [Fact]
    public async Task Admin_review_corrects_km_and_updates_vehicle()
    {
        var admin = _t.AddAdmin();
        var d = _t.AddDriver();
        var v = _t.AddVehicle();
        _t.CurrentUser.SignIn(d.User);
        var s = await _t.Shifts().StartAsync(Start(v.Id, 10_000, ocr: 10_900));
        await _t.Shifts().EndAsync(s.Id, End(10_300));

        _t.CurrentUser.SignIn(admin);
        var reviewed = await _t.Shifts().ReviewAsync(s.Id, new ReviewShiftRequest(null, 10_250, "Checked photo"));

        reviewed.EndKm.Should().Be(10_250);
        reviewed.ReviewedAt.Should().NotBeNull();
        (await _t.Db.Vehicles.SingleAsync()).CurrentOdometer.Should().Be(10_250);
        (await _t.Db.AuditLogs.AnyAsync(a => a.EntityType == "Shift" && a.Action == "Update")).Should().BeTrue();
    }

    [Fact]
    public async Task Photo_is_required()
    {
        var d = _t.AddDriver();
        var v = _t.AddVehicle();
        _t.CurrentUser.SignIn(d.User);
        var form = Start(v.Id, 10_000);
        form.Photo = null;

        var act = () => _t.Shifts().StartAsync(form);

        await act.Should().ThrowAsync<BusinessRuleException>().WithMessage("*photo*");
    }
}

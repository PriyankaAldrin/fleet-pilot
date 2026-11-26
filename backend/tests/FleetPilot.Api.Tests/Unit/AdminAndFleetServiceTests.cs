using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Tests.Support;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;

namespace FleetPilot.Api.Tests.Unit;

public class AdminAndFleetServiceTests : IDisposable
{
    private readonly TestDb _t = new();

    public void Dispose() => _t.Dispose();

    [Fact]
    public async Task Admin_cannot_delete_themselves()
    {
        var me = _t.AddAdmin();
        _t.CurrentUser.SignIn(me);

        var act = () => _t.Admins().DeleteAsync(me.Id);

        await act.Should().ThrowAsync<BusinessRuleException>().WithMessage("*own account*");
    }

    [Fact]
    public async Task Deleting_an_admin_is_soft_and_audited()
    {
        var me = _t.AddAdmin("me@x.io");
        var other = _t.AddAdmin("other@x.io");
        _t.CurrentUser.SignIn(me);

        await _t.Admins().DeleteAsync(other.Id);

        var row = await _t.Db.Users.SingleAsync(u => u.Id == other.Id);
        row.IsDeleted.Should().BeTrue();
        row.DeletedAt.Should().NotBeNull();
        (await _t.Admins().ListAsync(new UserListQuery())).Items.Should().ContainSingle(a => a.Id == me.Id);
        var log = await _t.Db.AuditLogs.SingleAsync(a => a.Action == "Delete");
        log.EntityType.Should().Be("User");
        log.EntityId.Should().Be(other.Id.ToString());
        log.UserEmail.Should().Be("me@x.io");
    }

    [Fact]
    public async Task Audit_never_stores_password_hashes()
    {
        var me = _t.AddAdmin();
        _t.CurrentUser.SignIn(me);

        await _t.Drivers().CreateAsync(new CreateDriverRequest("New Driver", "new@x.io", null, "Password1", "LIC-1", null));

        var logs = await _t.Db.AuditLogs.ToListAsync();
        logs.Should().NotBeEmpty();
        logs.Should().OnlyContain(l => l.Changes == null || !l.Changes.Contains("$2"));
    }

    [Fact]
    public async Task Email_must_be_unique_and_is_case_insensitive()
    {
        _t.CurrentUser.SignIn(_t.AddAdmin());
        await _t.Drivers().CreateAsync(new CreateDriverRequest("A", "Same@X.io", null, "Password1", "L1", null));

        var act = () => _t.Drivers().CreateAsync(new CreateDriverRequest("B", "same@x.io", null, "Password1", "L2", null));

        await act.Should().ThrowAsync<ConflictException>();
    }

    [Fact]
    public async Task Deleted_drivers_email_can_be_reused()
    {
        _t.CurrentUser.SignIn(_t.AddAdmin());
        var d = await _t.Drivers().CreateAsync(new CreateDriverRequest("A", "reuse@x.io", null, "Password1", "L1", null));
        await _t.Drivers().DeleteAsync(d.Id);

        var again = await _t.Drivers().CreateAsync(new CreateDriverRequest("A2", "reuse@x.io", null, "Password1", "L1", null));

        again.Email.Should().Be("reuse@x.io");
    }

    [Fact]
    public async Task Driver_search_and_paging()
    {
        _t.CurrentUser.SignIn(_t.AddAdmin());
        for (var i = 0; i < 25; i++)
            await _t.Drivers().CreateAsync(new CreateDriverRequest($"Driver {i:00}", $"d{i}@x.io", null, "Password1", $"L{i}", null));

        var page2 = await _t.Drivers().ListAsync(new UserListQuery { Page = 2, PageSize = 10 });
        var search = await _t.Drivers().ListAsync(new UserListQuery { Search = "Driver 07" });

        page2.TotalCount.Should().Be(25);
        page2.Items.Should().HaveCount(10);
        page2.Items[0].Name.Should().Be("Driver 10");
        search.Items.Should().ContainSingle().Which.Email.Should().Be("d7@x.io");
    }

    [Fact]
    public async Task Vehicle_in_use_cannot_be_deleted_and_is_not_available()
    {
        var d = _t.AddDriver();
        var v = _t.AddVehicle();
        var free = _t.AddVehicle("FREE 1");
        _t.Db.Shifts.Add(new Shift { ClientId = Guid.NewGuid(), DriverId = d.UserId, VehicleId = v.Id, Status = ShiftStatus.Active, StartTime = _t.Clock.UtcNow });
        await _t.Db.SaveChangesAsync();
        _t.CurrentUser.SignIn(_t.AddAdmin());

        var act = () => _t.Vehicles().DeleteAsync(v.Id);
        var available = await _t.Vehicles().AvailableAsync();

        await act.Should().ThrowAsync<BusinessRuleException>();
        available.Should().ContainSingle().Which.Id.Should().Be(free.Id);
        (await _t.Vehicles().GetAsync(v.Id)).InUse.Should().BeTrue();
    }

    [Fact]
    public async Task Plate_is_normalised_and_unique()
    {
        _t.CurrentUser.SignIn(_t.AddAdmin());
        var created = await _t.Vehicles().CreateAsync(new CreateVehicleRequest(" dxb a 123 ", "Lincoln", "Navigator", 2023, "Black", 500));

        var act = () => _t.Vehicles().CreateAsync(new CreateVehicleRequest("DXB A 123", "Lincoln", "Navigator", 2023, null, 0));

        created.PlateNo.Should().Be("DXB A 123");
        await act.Should().ThrowAsync<ConflictException>();
    }
}

using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Infrastructure.Reports;
using FleetPilot.Api.Options;
using FleetPilot.Api.Tests.Support;
using FluentAssertions;

namespace FleetPilot.Api.Tests.Unit;

public class ReportTests : IDisposable
{
    private readonly TestDb _t = new();

    public void Dispose() => _t.Dispose();

    private void AddShift(Driver d, Vehicle v, DateTime startUtc, double hours, int startKm, int? km, bool flagged = false)
    {
        _t.Db.Shifts.Add(new Shift
        {
            ClientId = Guid.NewGuid(),
            DriverId = d.UserId,
            VehicleId = v.Id,
            StartTime = startUtc,
            EndTime = km is null ? null : startUtc.AddHours(hours),
            StartKm = startKm,
            EndKm = km is null ? null : startKm + km,
            Status = km is null ? ShiftStatus.Active : ShiftStatus.Completed,
            IsFlagged = flagged,
        });
        _t.Db.SaveChanges();
    }

    [Fact]
    public async Task Driver_report_totals_and_averages()
    {
        var d = _t.AddDriver();
        var v1 = _t.AddVehicle("A 1");
        var v2 = _t.AddVehicle("A 2");
        // Dubai is UTC+4: 2026-03-01 05:00 local = 01:00 UTC.
        AddShift(d, v1, new DateTime(2026, 3, 1, 1, 0, 0, DateTimeKind.Utc), 8, 1000, 200);
        AddShift(d, v2, new DateTime(2026, 3, 2, 1, 0, 0, DateTimeKind.Utc), 10, 5000, 300, flagged: true);
        AddShift(d, v1, new DateTime(2026, 3, 3, 1, 0, 0, DateTimeKind.Utc), 0, 1200, null); // active: listed, not counted
        AddShift(d, v1, new DateTime(2026, 2, 28, 19, 0, 0, DateTimeKind.Utc), 4, 900, 50); // 23:00 local on Feb 28: outside

        var r = await _t.Reports().DriverReportAsync(d.UserId, new ReportQuery(new DateOnly(2026, 3, 1), new DateOnly(2026, 3, 3)));

        r.Shifts.Should().HaveCount(3);
        r.Totals.Shifts.Should().Be(3);
        r.Totals.CompletedShifts.Should().Be(2);
        r.Totals.TotalKm.Should().Be(500);
        r.Totals.TotalHours.Should().Be(18);
        r.Totals.AverageKmPerShift.Should().Be(250);
        r.Totals.AverageHoursPerShift.Should().Be(9);
        r.Totals.AverageKmPerHour.Should().Be(27.8);
        r.Totals.FlaggedShifts.Should().Be(1);
        r.Shifts[0].StartLocal.Should().Be(new DateTime(2026, 3, 1, 5, 0, 0));
    }

    [Fact]
    public async Task Vehicle_summary_has_a_row_per_vehicle()
    {
        var d = _t.AddDriver();
        var v1 = _t.AddVehicle("A 1");
        var v2 = _t.AddVehicle("A 2");
        AddShift(d, v1, new DateTime(2026, 3, 1, 6, 0, 0, DateTimeKind.Utc), 5, 1000, 120);

        var r = await _t.Reports().VehicleSummaryAsync(new ReportQuery(new DateOnly(2026, 3, 1), new DateOnly(2026, 3, 31)));

        r.Rows.Should().HaveCount(2);
        r.Rows[0].Name.Should().Be("A 1");
        r.Rows[0].Totals.TotalKm.Should().Be(120);
        r.Rows[1].Totals.Shifts.Should().Be(0);
    }

    [Fact]
    public async Task Exports_produce_pdf_and_xlsx_files()
    {
        QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;
        var d = _t.AddDriver();
        var v = _t.AddVehicle();
        AddShift(d, v, new DateTime(2026, 3, 1, 6, 0, 0, DateTimeKind.Utc), 5, 1000, 120);
        var exporter = new ReportExporter(Microsoft.Extensions.Options.Options.Create(new CompanyOptions()));
        var q = new ReportQuery(new DateOnly(2026, 3, 1), new DateOnly(2026, 3, 31));

        var pdf = exporter.ToPdf(await _t.Reports().DriverReportAsync(d.UserId, q));
        var xlsx = exporter.ToExcel(await _t.Reports().VehicleReportAsync(v.Id, q));
        var sumPdf = exporter.ToPdf(await _t.Reports().DriverSummaryAsync(q));
        var sumXlsx = exporter.ToExcel(await _t.Reports().VehicleSummaryAsync(q));

        System.Text.Encoding.ASCII.GetString(pdf.Content, 0, 4).Should().Be("%PDF");
        System.Text.Encoding.ASCII.GetString(sumPdf.Content, 0, 4).Should().Be("%PDF");
        xlsx.Content.Take(2).Should().Equal((byte)'P', (byte)'K');
        sumXlsx.Content.Take(2).Should().Equal((byte)'P', (byte)'K');
        pdf.FileName.Should().EndWith(".pdf");
        xlsx.FileName.Should().Be("vehicle-D-12345-20260301-20260331.xlsx");
    }
}

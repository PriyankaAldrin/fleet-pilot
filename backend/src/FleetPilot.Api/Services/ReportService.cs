using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace FleetPilot.Api.Services;

public interface IReportService
{
    Task<EntityReport> DriverReportAsync(int driverId, ReportQuery query, CancellationToken ct = default);
    Task<EntityReport> VehicleReportAsync(int vehicleId, ReportQuery query, CancellationToken ct = default);
    Task<SummaryReport> DriverSummaryAsync(ReportQuery query, CancellationToken ct = default);
    Task<SummaryReport> VehicleSummaryAsync(ReportQuery query, CancellationToken ct = default);
}

/// <summary>
/// Shifts belong to the period in which they started. Hours and km only count completed shifts;
/// active shifts are listed but add nothing to the totals yet.
/// </summary>
public sealed class ReportService(
    IRepository<Shift> shifts,
    IRepository<Driver> drivers,
    IRepository<Vehicle> vehicles,
    CompanyTime companyTime) : IReportService
{
    public async Task<EntityReport> DriverReportAsync(int driverId, ReportQuery query, CancellationToken ct = default)
    {
        // Deleted drivers stay reportable so their history is not lost.
        var driver = await drivers.Query().Include(d => d.User).FirstOrDefaultAsync(d => d.UserId == driverId, ct)
            ?? throw NotFoundException.For("Driver", driverId);
        var rows = await LoadAsync(query, s => s.DriverId == driverId, ct);
        var lines = rows.Select(s => Line(s, $"{s.Vehicle.PlateNo} ({s.Vehicle.Make} {s.Vehicle.Model})")).ToList();
        return new EntityReport("Driver", driverId, driver.User.Name,
            $"Licence {driver.LicenseNo}{(driver.User.Phone is null ? "" : $" · {driver.User.Phone}")}",
            query.From, query.To, companyTime.Zone.Id, Totals(rows), lines);
    }

    public async Task<EntityReport> VehicleReportAsync(int vehicleId, ReportQuery query, CancellationToken ct = default)
    {
        var vehicle = await vehicles.Query().FirstOrDefaultAsync(v => v.Id == vehicleId, ct)
            ?? throw NotFoundException.For("Vehicle", vehicleId);
        var rows = await LoadAsync(query, s => s.VehicleId == vehicleId, ct);
        var lines = rows.Select(s => Line(s, s.Driver.User.Name)).ToList();
        return new EntityReport("Vehicle", vehicleId, vehicle.PlateNo,
            $"{vehicle.Year} {vehicle.Make} {vehicle.Model}{(vehicle.Color is null ? "" : $" · {vehicle.Color}")} · odometer {vehicle.CurrentOdometer:N0} km",
            query.From, query.To, companyTime.Zone.Id, Totals(rows), lines);
    }

    public async Task<SummaryReport> DriverSummaryAsync(ReportQuery query, CancellationToken ct = default)
    {
        var rows = await LoadAsync(query, _ => true, ct);
        var list = await drivers.Query().Include(d => d.User).Where(d => !d.User.IsDeleted).ToListAsync(ct);
        // Include deleted drivers only if they drove in the period.
        var extra = rows.Select(r => r.Driver).Where(d => d.User.IsDeleted).DistinctBy(d => d.UserId);
        var summary = list.Concat(extra)
            .Select(d => new SummaryRow(d.UserId, d.User.Name, d.LicenseNo, Totals(rows.Where(r => r.DriverId == d.UserId).ToList())))
            .OrderByDescending(r => r.Totals.TotalKm).ThenBy(r => r.Name)
            .ToList();
        return new SummaryReport("Drivers", query.From, query.To, companyTime.Zone.Id, summary);
    }

    public async Task<SummaryReport> VehicleSummaryAsync(ReportQuery query, CancellationToken ct = default)
    {
        var rows = await LoadAsync(query, _ => true, ct);
        var list = await vehicles.Query().Where(v => !v.IsDeleted).ToListAsync(ct);
        var extra = rows.Select(r => r.Vehicle).Where(v => v.IsDeleted).DistinctBy(v => v.Id);
        var summary = list.Concat(extra)
            .Select(v => new SummaryRow(v.Id, v.PlateNo, $"{v.Make} {v.Model}", Totals(rows.Where(r => r.VehicleId == v.Id).ToList())))
            .OrderByDescending(r => r.Totals.TotalKm).ThenBy(r => r.Name)
            .ToList();
        return new SummaryReport("Vehicles", query.From, query.To, companyTime.Zone.Id, summary);
    }

    private async Task<List<Shift>> LoadAsync(ReportQuery query, System.Linq.Expressions.Expression<Func<Shift, bool>> filter, CancellationToken ct)
    {
        if (query.To < query.From) throw new BusinessRuleException("'To' date must be on or after 'From' date.");
        if (query.To.DayNumber - query.From.DayNumber > 366) throw new BusinessRuleException("Reports can cover at most one year.");
        var (from, to) = companyTime.RangeUtc(query.From, query.To);
        return await shifts.Query()
            .Include(s => s.Driver).ThenInclude(d => d.User)
            .Include(s => s.Vehicle)
            .Where(s => s.StartTime >= from && s.StartTime < to)
            .Where(filter)
            .OrderBy(s => s.StartTime)
            .AsNoTracking()
            .ToListAsync(ct);
    }

    private ReportShiftLine Line(Shift s, string counterpart) => new(
        s.Id,
        companyTime.ToLocal(s.StartTime),
        s.EndTime is null ? null : companyTime.ToLocal(s.EndTime.Value),
        counterpart,
        s.StartKm,
        s.EndKm,
        Distance(s),
        Math.Round(Hours(s), 2),
        s.IsFlagged);

    public static ReportTotals Totals(IReadOnlyCollection<Shift> rows)
    {
        var completed = rows.Where(r => r.Status == ShiftStatus.Completed).ToList();
        var hours = completed.Sum(Hours);
        var km = completed.Sum(Distance);
        var n = completed.Count;
        return new ReportTotals(
            rows.Count,
            n,
            Math.Round(hours, 2),
            km,
            n == 0 ? 0 : Math.Round(hours / n, 2),
            n == 0 ? 0 : Math.Round((double)km / n, 1),
            // Very short shifts (tests, mistakes) would give absurd speeds, so they count as zero.
            hours < 0.1 ? 0 : Math.Round(km / hours, 1),
            rows.Count(r => r.IsFlagged));
    }

    private static int Distance(Shift s) => s.EndKm is { } end ? end - s.StartKm : 0;

    private static double Hours(Shift s) => s.EndTime is { } end ? (end - s.StartTime).TotalHours : 0;
}

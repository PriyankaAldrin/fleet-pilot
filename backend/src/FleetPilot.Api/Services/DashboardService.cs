using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace FleetPilot.Api.Services;

public interface IDashboardService
{
    Task<DashboardDto> GetAsync(CancellationToken ct = default);
}

public sealed class DashboardService(
    IRepository<Shift> shifts,
    IRepository<Driver> drivers,
    IRepository<Vehicle> vehicles,
    CompanyTime companyTime) : IDashboardService
{
    public async Task<DashboardDto> GetAsync(CancellationToken ct = default)
    {
        var (from, to) = companyTime.RangeUtc(companyTime.Today, companyTime.Today);

        var details = shifts.Query().Include(s => s.Driver).ThenInclude(d => d.User).Include(s => s.Vehicle).AsNoTracking();
        var active = Mappings.ToDtos(await details.Where(s => s.Status == ShiftStatus.Active)
            .OrderBy(s => s.StartTime).ToListAsync(ct));

        var today = shifts.Query().Where(s => s.StartTime >= from && s.StartTime < to);
        var shiftsToday = await today.CountAsync(ct);
        var kmToday = await today.Where(s => s.EndKm != null).SumAsync(s => (int?)(s.EndKm!.Value - s.StartKm), ct) ?? 0;

        var needsReview = shifts.Query().Where(s => s.IsFlagged && s.ReviewedAt == null);
        var flaggedCount = await needsReview.CountAsync(ct);
        var recentFlagged = Mappings.ToDtos(await details.Where(s => s.IsFlagged && s.ReviewedAt == null)
            .OrderByDescending(s => s.StartTime).Take(10).ToListAsync(ct));

        var activeDrivers = await drivers.Query().CountAsync(d => !d.User.IsDeleted && d.User.IsActive, ct);
        var activeVehicles = await vehicles.Query().CountAsync(v => !v.IsDeleted && v.IsActive, ct);

        return new DashboardDto(active.Count, shiftsToday, kmToday, flaggedCount, activeDrivers, activeVehicles, active, recentFlagged);
    }
}

using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace FleetPilot.Api.Services;

public interface IVehicleService
{
    Task<PagedResult<VehicleDto>> ListAsync(VehicleListQuery query, CancellationToken ct = default);
    Task<IReadOnlyList<VehicleDto>> AvailableAsync(CancellationToken ct = default);
    Task<VehicleDto> GetAsync(int id, CancellationToken ct = default);
    Task<VehicleDto> CreateAsync(CreateVehicleRequest request, CancellationToken ct = default);
    Task<VehicleDto> UpdateAsync(int id, UpdateVehicleRequest request, CancellationToken ct = default);
    Task DeleteAsync(int id, CancellationToken ct = default);
}

public sealed class VehicleService(
    IRepository<Vehicle> vehicles,
    IRepository<Shift> shifts,
    IUnitOfWork uow) : IVehicleService
{
    private IQueryable<Vehicle> NotDeleted => vehicles.Query().Where(v => !v.IsDeleted);

    public async Task<PagedResult<VehicleDto>> ListAsync(VehicleListQuery query, CancellationToken ct = default)
    {
        var q = NotDeleted;
        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var s = query.Search.Trim();
            q = q.Where(v => v.PlateNo.Contains(s) || v.Make.Contains(s) || v.Model.Contains(s) || (v.Color != null && v.Color.Contains(s)));
        }
        if (query.IsActive is { } active) q = q.Where(v => v.IsActive == active);
        var page = await q.OrderBy(v => v.PlateNo).ToPagedAsync(query, ct);
        var inUse = await InUseIdsAsync(page.Items.Select(v => v.Id).ToList(), ct);
        return new(page.Items.Select(v => ToDto(v, inUse)).ToList(), page.Page, page.PageSize, page.TotalCount);
    }

    public async Task<IReadOnlyList<VehicleDto>> AvailableAsync(CancellationToken ct = default)
    {
        var list = await NotDeleted
            .Where(v => v.IsActive && !shifts.Query().Any(s => s.VehicleId == v.Id && s.Status == ShiftStatus.Active))
            .OrderBy(v => v.PlateNo)
            .ToListAsync(ct);
        return list.Select(v => ToDto(v, EmptySet)).ToList();
    }

    public async Task<VehicleDto> GetAsync(int id, CancellationToken ct = default)
    {
        var v = await Load(id, ct);
        return ToDto(v, await InUseIdsAsync([id], ct));
    }

    public async Task<VehicleDto> CreateAsync(CreateVehicleRequest request, CancellationToken ct = default)
    {
        var plate = NormalizePlate(request.PlateNo);
        await EnsurePlateFreeAsync(plate, null, ct);
        var v = new Vehicle
        {
            PlateNo = plate,
            Make = request.Make.Trim(),
            Model = request.Model.Trim(),
            Year = request.Year,
            Color = request.Color?.Trim(),
            CurrentOdometer = request.CurrentOdometer,
            IsActive = request.IsActive,
        };
        vehicles.Add(v);
        await uow.SaveChangesAsync(ct);
        return ToDto(v, EmptySet);
    }

    public async Task<VehicleDto> UpdateAsync(int id, UpdateVehicleRequest request, CancellationToken ct = default)
    {
        var v = await Load(id, ct);
        var plate = NormalizePlate(request.PlateNo);
        await EnsurePlateFreeAsync(plate, id, ct);
        var inUse = await InUseIdsAsync([id], ct);
        if (inUse.Contains(id) && !request.IsActive)
            throw new BusinessRuleException("This vehicle is in an active shift. End the shift before deactivating it.");

        v.PlateNo = plate;
        v.Make = request.Make.Trim();
        v.Model = request.Model.Trim();
        v.Year = request.Year;
        v.Color = request.Color?.Trim();
        v.CurrentOdometer = request.CurrentOdometer;
        v.IsActive = request.IsActive;
        await uow.SaveChangesAsync(ct);
        return ToDto(v, inUse);
    }

    public async Task DeleteAsync(int id, CancellationToken ct = default)
    {
        var v = await Load(id, ct);
        if ((await InUseIdsAsync([id], ct)).Contains(id))
            throw new BusinessRuleException("This vehicle is in an active shift. End the shift before deleting it.");
        vehicles.Remove(v);
        await uow.SaveChangesAsync(ct);
    }

    private static readonly IReadOnlySet<int> EmptySet = new HashSet<int>();

    private VehicleDto ToDto(Vehicle v, IReadOnlySet<int> inUse) =>
        v.ToDto(inUse.Contains(v.Id));

    private async Task<IReadOnlySet<int>> InUseIdsAsync(IReadOnlyCollection<int> ids, CancellationToken ct) =>
        (await shifts.Query().Where(s => s.Status == ShiftStatus.Active && ids.Contains(s.VehicleId))
            .Select(s => s.VehicleId).ToListAsync(ct)).ToHashSet();

    private async Task<Vehicle> Load(int id, CancellationToken ct) =>
        await NotDeleted.FirstOrDefaultAsync(v => v.Id == id, ct) ?? throw NotFoundException.For("Vehicle", id);

    private async Task EnsurePlateFreeAsync(string plate, int? exceptId, CancellationToken ct)
    {
        if (await NotDeleted.AnyAsync(v => v.PlateNo == plate && v.Id != exceptId, ct))
            throw new ConflictException($"A vehicle with plate {plate} already exists.");
    }

    private static string NormalizePlate(string plate) => plate.Trim().ToUpperInvariant();
}

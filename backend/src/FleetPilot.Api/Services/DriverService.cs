using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace FleetPilot.Api.Services;

public interface IDriverService
{
    Task<PagedResult<DriverDto>> ListAsync(UserListQuery query, CancellationToken ct = default);
    Task<DriverDto> GetAsync(int id, CancellationToken ct = default);
    Task<DriverDto> CreateAsync(CreateDriverRequest request, CancellationToken ct = default);
    Task<DriverDto> UpdateAsync(int id, UpdateDriverRequest request, CancellationToken ct = default);
    Task DeleteAsync(int id, CancellationToken ct = default);
}

public sealed class DriverService(
    IRepository<User> users,
    IRepository<Driver> drivers,
    IRepository<Shift> shifts,
    IUnitOfWork uow,
    IPasswordHasher hasher) : IDriverService
{
    private IQueryable<Driver> Active => drivers.Query().Include(d => d.User).Where(d => !d.User.IsDeleted);

    public async Task<PagedResult<DriverDto>> ListAsync(UserListQuery query, CancellationToken ct = default)
    {
        var q = Active;
        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var s = query.Search.Trim();
            q = q.Where(d => d.User.Name.Contains(s) || d.User.Email.Contains(s) || d.LicenseNo.Contains(s)
                             || (d.User.Phone != null && d.User.Phone.Contains(s)));
        }
        if (query.IsActive is { } active) q = q.Where(d => d.User.IsActive == active);
        return await q.OrderBy(d => d.User.Name).Select(Mappings.DriverProjection).ToPagedAsync(query, ct);
    }

    public async Task<DriverDto> GetAsync(int id, CancellationToken ct = default) =>
        (await Load(id, ct)).ToDto();

    public async Task<DriverDto> CreateAsync(CreateDriverRequest request, CancellationToken ct = default)
    {
        var email = UserRules.NormalizeEmail(request.Email);
        await UserRules.EnsureEmailFreeAsync(users, email, null, ct);
        var driver = new Driver
        {
            LicenseNo = request.LicenseNo.Trim(),
            LicenseExpiry = request.LicenseExpiry,
            User = new User
            {
                Name = request.Name.Trim(),
                Email = email,
                Phone = request.Phone?.Trim(),
                PasswordHash = hasher.Hash(request.Password),
                Role = UserRole.Driver,
                IsActive = request.IsActive,
            },
        };
        drivers.Add(driver);
        await uow.SaveChangesAsync(ct);
        return driver.ToDto();
    }

    public async Task<DriverDto> UpdateAsync(int id, UpdateDriverRequest request, CancellationToken ct = default)
    {
        var driver = await Load(id, ct);
        var email = UserRules.NormalizeEmail(request.Email);
        await UserRules.EnsureEmailFreeAsync(users, email, id, ct);

        driver.User.Name = request.Name.Trim();
        driver.User.Email = email;
        driver.User.Phone = request.Phone?.Trim();
        driver.User.IsActive = request.IsActive;
        driver.LicenseNo = request.LicenseNo.Trim();
        driver.LicenseExpiry = request.LicenseExpiry;
        if (!string.IsNullOrEmpty(request.NewPassword)) driver.User.PasswordHash = hasher.Hash(request.NewPassword);
        await uow.SaveChangesAsync(ct);
        return driver.ToDto();
    }

    public async Task DeleteAsync(int id, CancellationToken ct = default)
    {
        var driver = await Load(id, ct);
        if (await shifts.Query().AnyAsync(s => s.DriverId == id && s.Status == ShiftStatus.Active, ct))
            throw new BusinessRuleException("This driver has an active shift. End it before deleting the driver.");
        users.Remove(driver.User); // soft delete keeps the shift history for reports
        await uow.SaveChangesAsync(ct);
    }

    private async Task<Driver> Load(int id, CancellationToken ct) =>
        await Active.FirstOrDefaultAsync(d => d.UserId == id, ct) ?? throw NotFoundException.For("Driver", id);
}

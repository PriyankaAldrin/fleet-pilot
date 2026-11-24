using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace FleetPilot.Api.Services;

public interface IAdminService
{
    Task<PagedResult<AdminDto>> ListAsync(UserListQuery query, CancellationToken ct = default);
    Task<AdminDto> GetAsync(int id, CancellationToken ct = default);
    Task<AdminDto> CreateAsync(CreateAdminRequest request, CancellationToken ct = default);
    Task<AdminDto> UpdateAsync(int id, UpdateAdminRequest request, CancellationToken ct = default);
    Task DeleteAsync(int id, CancellationToken ct = default);
}

public sealed class AdminService(
    IRepository<User> users,
    IUnitOfWork uow,
    IPasswordHasher hasher,
    ICurrentUser currentUser) : IAdminService
{
    private IQueryable<User> Admins => users.Query().Where(u => !u.IsDeleted && u.Role == UserRole.Admin);

    public async Task<PagedResult<AdminDto>> ListAsync(UserListQuery query, CancellationToken ct = default)
    {
        var q = Admins;
        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var s = query.Search.Trim();
            q = q.Where(u => u.Name.Contains(s) || u.Email.Contains(s) || (u.Phone != null && u.Phone.Contains(s)));
        }
        if (query.IsActive is { } active) q = q.Where(u => u.IsActive == active);
        return await q.OrderBy(u => u.Name).Select(Mappings.AdminProjection).ToPagedAsync(query, ct);
    }

    public async Task<AdminDto> GetAsync(int id, CancellationToken ct = default) =>
        (await Load(id, ct)).ToAdminDto();

    public async Task<AdminDto> CreateAsync(CreateAdminRequest request, CancellationToken ct = default)
    {
        var email = UserRules.NormalizeEmail(request.Email);
        await UserRules.EnsureEmailFreeAsync(users, email, null, ct);
        var user = new User
        {
            Name = request.Name.Trim(),
            Email = email,
            Phone = request.Phone?.Trim(),
            PasswordHash = hasher.Hash(request.Password),
            Role = UserRole.Admin,
            IsActive = request.IsActive,
        };
        users.Add(user);
        await uow.SaveChangesAsync(ct);
        return user.ToAdminDto();
    }

    public async Task<AdminDto> UpdateAsync(int id, UpdateAdminRequest request, CancellationToken ct = default)
    {
        var user = await Load(id, ct);
        var email = UserRules.NormalizeEmail(request.Email);
        await UserRules.EnsureEmailFreeAsync(users, email, id, ct);
        if (id == currentUser.Id && !request.IsActive)
            throw new BusinessRuleException("You cannot deactivate your own account.");
        if (user.IsActive && !request.IsActive) await EnsureAnotherActiveAdminAsync(id, ct);

        user.Name = request.Name.Trim();
        user.Email = email;
        user.Phone = request.Phone?.Trim();
        user.IsActive = request.IsActive;
        if (!string.IsNullOrEmpty(request.NewPassword)) user.PasswordHash = hasher.Hash(request.NewPassword);
        await uow.SaveChangesAsync(ct);
        return user.ToAdminDto();
    }

    public async Task DeleteAsync(int id, CancellationToken ct = default)
    {
        if (id == currentUser.Id) throw new BusinessRuleException("You cannot delete your own account.");
        var user = await Load(id, ct);
        await EnsureAnotherActiveAdminAsync(id, ct);
        users.Remove(user); // soft delete, see AppDbContext
        await uow.SaveChangesAsync(ct);
    }

    private async Task<User> Load(int id, CancellationToken ct) =>
        await Admins.FirstOrDefaultAsync(u => u.Id == id, ct) ?? throw NotFoundException.For("Admin", id);

    private async Task EnsureAnotherActiveAdminAsync(int exceptId, CancellationToken ct)
    {
        if (!await Admins.AnyAsync(u => u.Id != exceptId && u.IsActive, ct))
            throw new BusinessRuleException("At least one active admin must remain.");
    }
}

internal static class UserRules
{
    public static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();

    public static async Task EnsureEmailFreeAsync(IRepository<User> users, string email, int? exceptId, CancellationToken ct)
    {
        if (await users.Query().AnyAsync(u => !u.IsDeleted && u.Email == email && u.Id != exceptId, ct))
            throw new ConflictException($"A user with email {email} already exists.");
    }
}

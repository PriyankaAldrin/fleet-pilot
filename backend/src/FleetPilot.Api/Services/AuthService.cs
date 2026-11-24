using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace FleetPilot.Api.Services;

public interface IAuthService
{
    Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken ct = default);
    Task<AuthResponse> RefreshAsync(string refreshToken, CancellationToken ct = default);
    Task LogoutAsync(string refreshToken, CancellationToken ct = default);
    Task<UserDto> MeAsync(CancellationToken ct = default);
    Task ChangePasswordAsync(ChangePasswordRequest request, CancellationToken ct = default);
}

public sealed class AuthService(
    IRepository<User> users,
    IRepository<RefreshToken> refreshTokens,
    IUnitOfWork uow,
    IPasswordHasher hasher,
    ITokenService tokens,
    ICurrentUser currentUser,
    IClock clock) : IAuthService
{
    private const string InvalidCredentials = "Email or password is incorrect.";

    public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken ct = default)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var user = await users.Query().FirstOrDefaultAsync(u => u.Email == email && !u.IsDeleted, ct);
        if (user is null || !hasher.Verify(request.Password, user.PasswordHash))
            throw new UnauthorizedException(InvalidCredentials);
        if (!user.IsActive)
            throw new UnauthorizedException("This account is disabled. Contact your administrator.");

        return await IssueAsync(user, null, ct);
    }

    public async Task<AuthResponse> RefreshAsync(string refreshToken, CancellationToken ct = default)
    {
        var hash = tokens.HashRefreshToken(refreshToken);
        var stored = await refreshTokens.Query().Include(t => t.User)
            .FirstOrDefaultAsync(t => t.TokenHash == hash, ct)
            ?? throw new UnauthorizedException("Session expired. Please sign in again.");

        var now = clock.UtcNow;
        if (stored.RevokedAt is not null)
        {
            // A rotated token was used again: treat as theft and end every session of this user.
            await RevokeAllAsync(stored.UserId, now, ct);
            throw new UnauthorizedException("Session expired. Please sign in again.");
        }
        if (!stored.IsActive(now) || stored.User.IsDeleted || !stored.User.IsActive)
            throw new UnauthorizedException("Session expired. Please sign in again.");

        return await IssueAsync(stored.User, stored, ct);
    }

    public async Task LogoutAsync(string refreshToken, CancellationToken ct = default)
    {
        var hash = tokens.HashRefreshToken(refreshToken);
        var stored = await refreshTokens.Query().FirstOrDefaultAsync(t => t.TokenHash == hash, ct);
        if (stored is { RevokedAt: null })
        {
            stored.RevokedAt = clock.UtcNow;
            await uow.SaveChangesAsync(ct);
        }
    }

    public async Task<UserDto> MeAsync(CancellationToken ct = default)
    {
        var id = currentUser.RequireId();
        var user = await users.Query().FirstOrDefaultAsync(u => u.Id == id && !u.IsDeleted, ct)
            ?? throw new UnauthorizedException("Account not found.");
        return user.ToDto();
    }

    public async Task ChangePasswordAsync(ChangePasswordRequest request, CancellationToken ct = default)
    {
        var id = currentUser.RequireId();
        var user = await users.Query().FirstAsync(u => u.Id == id, ct);
        if (!hasher.Verify(request.CurrentPassword, user.PasswordHash))
            throw new BusinessRuleException("Current password is incorrect.");
        user.PasswordHash = hasher.Hash(request.NewPassword);
        await RevokeAllAsync(user.Id, clock.UtcNow, ct);
    }

    private async Task<AuthResponse> IssueAsync(User user, RefreshToken? replacing, CancellationToken ct)
    {
        var (access, accessExp) = tokens.CreateAccessToken(user);
        var (refresh, refreshHash, refreshExp) = tokens.CreateRefreshToken();
        var entity = new RefreshToken
        {
            UserId = user.Id,
            TokenHash = refreshHash,
            CreatedAt = clock.UtcNow,
            ExpiresAt = refreshExp,
        };
        refreshTokens.Add(entity);
        if (replacing is not null) replacing.RevokedAt = clock.UtcNow;
        await uow.SaveChangesAsync(ct);
        if (replacing is not null)
        {
            replacing.ReplacedByTokenId = entity.Id;
            await uow.SaveChangesAsync(ct);
        }
        return new AuthResponse(access, accessExp, refresh, refreshExp, user.ToDto());
    }

    private async Task RevokeAllAsync(int userId, DateTime now, CancellationToken ct)
    {
        var active = await refreshTokens.Query().Where(t => t.UserId == userId && t.RevokedAt == null).ToListAsync(ct);
        foreach (var t in active) t.RevokedAt = now;
        await uow.SaveChangesAsync(ct);
    }
}

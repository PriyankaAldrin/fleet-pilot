using System.Security.Claims;
using FleetPilot.Api.Domain;

namespace FleetPilot.Api.Common;

public interface ICurrentUser
{
    int? Id { get; }
    string? Email { get; }
    UserRole? Role { get; }
    bool IsAdmin => Role == UserRole.Admin;
    int RequireId() => Id ?? throw new UnauthorizedException("Not signed in.");
}

public sealed class HttpCurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    private ClaimsPrincipal? Principal => accessor.HttpContext?.User;

    public int? Id =>
        int.TryParse(Principal?.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;

    public string? Email => Principal?.FindFirstValue(ClaimTypes.Email);

    public UserRole? Role =>
        Enum.TryParse<UserRole>(Principal?.FindFirstValue(ClaimTypes.Role), out var role) ? role : null;
}

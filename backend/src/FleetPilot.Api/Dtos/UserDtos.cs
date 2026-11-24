using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;

namespace FleetPilot.Api.Dtos;

public record UserDto(int Id, string Name, string Email, string? Phone, UserRole Role, bool IsActive, DateTime CreatedAt);

public record AdminDto(int Id, string Name, string Email, string? Phone, bool IsActive, DateTime CreatedAt);

public record CreateAdminRequest(string Name, string Email, string? Phone, string Password, bool IsActive = true);

public record UpdateAdminRequest(string Name, string Email, string? Phone, bool IsActive, string? NewPassword);

public record DriverDto(
    int Id,
    string Name,
    string Email,
    string? Phone,
    string LicenseNo,
    DateOnly? LicenseExpiry,
    bool IsActive,
    DateTime CreatedAt);

public record CreateDriverRequest(
    string Name,
    string Email,
    string? Phone,
    string Password,
    string LicenseNo,
    DateOnly? LicenseExpiry,
    bool IsActive = true);

public record UpdateDriverRequest(
    string Name,
    string Email,
    string? Phone,
    string LicenseNo,
    DateOnly? LicenseExpiry,
    bool IsActive,
    string? NewPassword);

public record UserListQuery : PageQuery
{
    public bool? IsActive { get; init; }
}

using FleetPilot.Api.Common;

namespace FleetPilot.Api.Dtos;

public record VehicleDto(
    int Id,
    string PlateNo,
    string Make,
    string Model,
    int Year,
    string? Color,
    int CurrentOdometer,
    bool IsActive,
    bool InUse,
    DateTime CreatedAt);

public record CreateVehicleRequest(string PlateNo, string Make, string Model, int Year, string? Color, int CurrentOdometer, bool IsActive = true);

public record UpdateVehicleRequest(string PlateNo, string Make, string Model, int Year, string? Color, int CurrentOdometer, bool IsActive);

public record VehicleListQuery : PageQuery
{
    public bool? IsActive { get; init; }
}

using System.Linq.Expressions;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;

namespace FleetPilot.Api.Services;

/// <summary>
/// Entity to DTO mapping. Written by hand (instead of AutoMapper) so there is no licence or
/// vulnerable package to track, and so the projections are plain LINQ that EF can translate.
/// </summary>
public static class Mappings
{
    public static UserDto ToDto(this User u) => new(u.Id, u.Name, u.Email, u.Phone, u.Role, u.IsActive, u.CreatedAt);

    public static readonly Expression<Func<User, AdminDto>> AdminProjection =
        u => new AdminDto(u.Id, u.Name, u.Email, u.Phone, u.IsActive, u.CreatedAt);

    private static readonly Func<User, AdminDto> AdminCompiled = AdminProjection.Compile();
    public static AdminDto ToAdminDto(this User u) => AdminCompiled(u);

    public static readonly Expression<Func<Driver, DriverDto>> DriverProjection =
        d => new DriverDto(d.UserId, d.User.Name, d.User.Email, d.User.Phone, d.LicenseNo, d.LicenseExpiry, d.User.IsActive, d.User.CreatedAt);

    private static readonly Func<Driver, DriverDto> DriverCompiled = DriverProjection.Compile();
    public static DriverDto ToDto(this Driver d) => DriverCompiled(d);

    public static VehicleDto ToDto(this Vehicle v, bool inUse) =>
        new(v.Id, v.PlateNo, v.Make, v.Model, v.Year, v.Color, v.CurrentOdometer, v.IsActive, inUse, v.CreatedAt);

    public static readonly Expression<Func<AuditLog, AuditLogDto>> AuditProjection =
        l => new AuditLogDto(l.Id, l.UserId, l.UserEmail, l.Action, l.EntityType, l.EntityId, l.Changes, l.Timestamp);

    /// <summary>Requires Driver.User and Vehicle to be loaded.</summary>
    public static ShiftDto ToDto(this Shift s) => new(
        s.Id,
        s.ClientId,
        s.DriverId,
        s.Driver.User.Name,
        s.VehicleId,
        s.Vehicle.PlateNo,
        $"{s.Vehicle.Make} {s.Vehicle.Model}",
        s.StartTime,
        s.EndTime,
        s.StartKm,
        s.EndKm,
        s.EndKm - s.StartKm,
        s.EndTime is { } end ? Math.Round((end - s.StartTime).TotalHours, 2) : null,
        s.StartPhotoUrl is null ? null : $"/api/v1/shifts/{s.Id}/photos/start",
        s.EndPhotoUrl is null ? null : $"/api/v1/shifts/{s.Id}/photos/end",
        s.StartKmOcr,
        s.EndKmOcr,
        s.StartKmServerOcr,
        s.EndKmServerOcr,
        s.OcrConfidence,
        s.KmManuallyEdited,
        s.StartLatitude,
        s.StartLongitude,
        s.EndLatitude,
        s.EndLongitude,
        s.RecordedOffline,
        s.Status,
        s.Notes,
        s.IsFlagged,
        SplitReasons(s.FlagReasons),
        s.ReviewedAt,
        s.ReviewNotes);

    public static List<ShiftDto> ToDtos(this IEnumerable<Shift> shifts) => shifts.Select(ToDto).ToList();

    public static IReadOnlyList<string> SplitReasons(string? s) =>
        string.IsNullOrWhiteSpace(s)
            ? Array.Empty<string>()
            : s.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
}

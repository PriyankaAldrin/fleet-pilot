using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;

namespace FleetPilot.Api.Dtos;

public record ShiftDto(
    int Id,
    Guid ClientId,
    int DriverId,
    string DriverName,
    int VehicleId,
    string VehiclePlateNo,
    string VehicleDescription,
    DateTime StartTime,
    DateTime? EndTime,
    int StartKm,
    int? EndKm,
    int? DistanceKm,
    double? DurationHours,
    string? StartPhotoUrl,
    string? EndPhotoUrl,
    int? StartKmOcr,
    int? EndKmOcr,
    int? StartKmServerOcr,
    int? EndKmServerOcr,
    double? OcrConfidence,
    bool KmManuallyEdited,
    double? StartLatitude,
    double? StartLongitude,
    double? EndLatitude,
    double? EndLongitude,
    bool RecordedOffline,
    ShiftStatus Status,
    string? Notes,
    bool IsFlagged,
    IReadOnlyList<string> FlagReasons,
    DateTime? ReviewedAt,
    string? ReviewNotes);

/// <summary>Multipart form posted by the app when a shift starts.</summary>
public class StartShiftForm
{
    public Guid ClientId { get; set; }
    public int VehicleId { get; set; }
    /// <summary>The km value the driver confirmed.</summary>
    public int StartKm { get; set; }
    /// <summary>The km value ML Kit read on the device, if any.</summary>
    public int? OcrKm { get; set; }
    public double? OcrConfidence { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    /// <summary>Device time the photo was taken. Only used when the shift was recorded offline.</summary>
    public DateTime? CapturedAt { get; set; }
    public bool RecordedOffline { get; set; }
    public string? Notes { get; set; }
    public IFormFile? Photo { get; set; }
}

/// <summary>Multipart form posted by the app when a shift ends.</summary>
public class EndShiftForm
{
    public int EndKm { get; set; }
    public int? OcrKm { get; set; }
    public double? OcrConfidence { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public DateTime? CapturedAt { get; set; }
    public bool RecordedOffline { get; set; }
    public string? Notes { get; set; }
    public IFormFile? Photo { get; set; }
}

public record ReviewShiftRequest(int? StartKm, int? EndKm, string? ReviewNotes);

public record ShiftListQuery : PageQuery
{
    public int? DriverId { get; init; }
    public int? VehicleId { get; init; }
    public DateOnly? From { get; init; }
    public DateOnly? To { get; init; }
    public ShiftStatus? Status { get; init; }
    public bool? Flagged { get; init; }
    /// <summary>When true, only flagged shifts that have not been reviewed yet.</summary>
    public bool? NeedsReview { get; init; }
}

public record DashboardDto(
    int ActiveShifts,
    int ShiftsToday,
    int KmToday,
    int FlaggedAwaitingReview,
    int ActiveDrivers,
    int ActiveVehicles,
    IReadOnlyList<ShiftDto> ActiveShiftList,
    IReadOnlyList<ShiftDto> RecentFlagged);

public record AuditLogDto(long Id, int? UserId, string? UserEmail, string Action, string EntityType, string EntityId, string? Changes, DateTime Timestamp);

public record AuditLogQuery : PageQuery
{
    public string? EntityType { get; init; }
    public string? EntityId { get; init; }
}

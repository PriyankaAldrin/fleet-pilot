namespace FleetPilot.Api.Dtos;

public record ReportQuery(DateOnly From, DateOnly To);

public record ReportShiftLine(
    int ShiftId,
    DateTime StartLocal,
    DateTime? EndLocal,
    string Counterpart,
    int StartKm,
    int? EndKm,
    int DistanceKm,
    double Hours,
    bool IsFlagged);

public record ReportTotals(
    int Shifts,
    int CompletedShifts,
    double TotalHours,
    int TotalKm,
    double AverageHoursPerShift,
    double AverageKmPerShift,
    double AverageKmPerHour,
    int FlaggedShifts);

/// <summary>Report for one driver or one vehicle.</summary>
public record EntityReport(
    string Kind,
    int Id,
    string Title,
    string Subtitle,
    DateOnly From,
    DateOnly To,
    string TimeZone,
    ReportTotals Totals,
    IReadOnlyList<ReportShiftLine> Shifts);

public record SummaryRow(int Id, string Name, string Detail, ReportTotals Totals);

/// <summary>One row per driver or per vehicle for the period.</summary>
public record SummaryReport(string Kind, DateOnly From, DateOnly To, string TimeZone, IReadOnlyList<SummaryRow> Rows);

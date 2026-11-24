using FleetPilot.Api.Options;
using Microsoft.Extensions.Options;

namespace FleetPilot.Api.Common;

/// <summary>Converts between the company's local calendar days and UTC instants.</summary>
public sealed class CompanyTime(IOptions<CompanyOptions> options, IClock clock)
{
    private readonly TimeZoneInfo _zone = TimeZoneInfo.FindSystemTimeZoneById(options.Value.TimeZone);

    public TimeZoneInfo Zone => _zone;

    public DateOnly Today => DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(clock.UtcNow, _zone));

    /// <summary>UTC instant at which the given local day starts.</summary>
    public DateTime StartOfDayUtc(DateOnly day) =>
        TimeZoneInfo.ConvertTimeToUtc(day.ToDateTime(TimeOnly.MinValue, DateTimeKind.Unspecified), _zone);

    /// <summary>Inclusive local date range converted to a half open UTC range [from, to).</summary>
    public (DateTime FromUtc, DateTime ToUtc) RangeUtc(DateOnly from, DateOnly to) =>
        (StartOfDayUtc(from), StartOfDayUtc(to.AddDays(1)));

    public DateTime ToLocal(DateTime utc) =>
        TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), _zone);
}

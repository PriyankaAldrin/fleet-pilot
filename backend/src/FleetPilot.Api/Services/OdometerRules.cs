using FleetPilot.Api.Options;
using Microsoft.Extensions.Options;

namespace FleetPilot.Api.Services;

/// <summary>One odometer reading as submitted by the app.</summary>
public record OdometerReading(int ConfirmedKm, int? DeviceOcrKm, double? DeviceConfidence, int? ServerOcrKm, double? ServerConfidence)
{
    /// <summary>True when the driver typed a value instead of accepting what the device read.</summary>
    public bool ManuallyEdited => DeviceOcrKm != ConfirmedKm;
}

/// <summary>
/// Decides whether an odometer reading needs an admin to look at it. Pure logic, no I/O.
/// </summary>
public sealed class OdometerRules(IOptions<OdometerRulesOptions> options)
{
    private readonly OdometerRulesOptions _opt = options.Value;

    public OdometerRulesOptions Options => _opt;

    public IReadOnlyList<string> CheckStart(OdometerReading reading, int vehicleLastOdometer)
    {
        var reasons = CheckReading("Start", reading);
        if (reading.ConfirmedKm < vehicleLastOdometer)
            reasons.Add($"Start reading {reading.ConfirmedKm} km is below the vehicle's last odometer {vehicleLastOdometer} km.");
        else if (reading.ConfirmedKm - vehicleLastOdometer > _opt.MaxGapBetweenShiftsKm)
            reasons.Add($"Start reading is {reading.ConfirmedKm - vehicleLastOdometer} km above the vehicle's last odometer; driving may be unlogged.");
        return reasons;
    }

    public IReadOnlyList<string> CheckEnd(OdometerReading reading, int startKm)
    {
        var reasons = CheckReading("End", reading);
        var distance = reading.ConfirmedKm - startKm;
        if (distance > _opt.MaxKmPerShift)
            reasons.Add($"Shift distance {distance} km is above the {_opt.MaxKmPerShift} km limit.");
        return reasons;
    }

    private List<string> CheckReading(string label, OdometerReading r)
    {
        var reasons = new List<string>();
        if (r.DeviceOcrKm is null)
            reasons.Add($"{label}: no reading was detected on the photo; value was typed by the driver.");
        else if (r.ManuallyEdited)
            reasons.Add($"{label}: driver changed the reading from {r.DeviceOcrKm} to {r.ConfirmedKm} km.");

        if (r.DeviceConfidence is { } dc && dc < _opt.MinOcrConfidence)
            reasons.Add($"{label}: low confidence on the device reading ({dc:P0}).");

        if (r.ServerOcrKm is { } server && Math.Abs(server - r.ConfirmedKm) > _opt.ServerOcrToleranceKm)
            reasons.Add($"{label}: server read {server} km but {r.ConfirmedKm} km was submitted.");
        if (r.ServerConfidence is { } sc && sc < _opt.MinOcrConfidence)
            reasons.Add($"{label}: low confidence on the server reading ({sc:P0}).");
        return reasons;
    }

    public static double? LowestConfidence(params double?[] values)
    {
        var present = values.Where(v => v.HasValue).Select(v => v!.Value).ToList();
        return present.Count == 0 ? null : present.Min();
    }
}

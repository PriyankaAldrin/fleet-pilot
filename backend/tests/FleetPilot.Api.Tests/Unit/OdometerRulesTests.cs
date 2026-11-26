using FleetPilot.Api.Options;
using FleetPilot.Api.Services;
using FluentAssertions;

namespace FleetPilot.Api.Tests.Unit;

public class OdometerRulesTests
{
    private readonly OdometerRules _rules = new(Microsoft.Extensions.Options.Options.Create(new OdometerRulesOptions()));

    [Fact]
    public void Clean_reading_has_no_flags() =>
        _rules.CheckStart(new OdometerReading(10_010, 10_010, 0.97, null, null), 10_000).Should().BeEmpty();

    [Fact]
    public void Edited_reading_is_flagged() =>
        _rules.CheckStart(new OdometerReading(10_010, 10_070, 0.97, null, null), 10_000)
            .Should().ContainSingle(r => r.Contains("changed the reading"));

    [Fact]
    public void Missing_device_reading_is_flagged() =>
        _rules.CheckStart(new OdometerReading(10_000, null, null, null, null), 10_000)
            .Should().ContainSingle(r => r.Contains("no reading was detected"));

    [Fact]
    public void Low_confidence_is_flagged() =>
        _rules.CheckStart(new OdometerReading(10_000, 10_000, 0.5, null, null), 10_000)
            .Should().ContainSingle(r => r.Contains("low confidence"));

    [Fact]
    public void Start_below_last_odometer_is_flagged() =>
        _rules.CheckStart(new OdometerReading(9_000, 9_000, 0.99, null, null), 10_000)
            .Should().ContainSingle(r => r.Contains("below the vehicle's last odometer"));

    [Fact]
    public void Large_gap_since_last_shift_is_flagged() =>
        _rules.CheckStart(new OdometerReading(10_200, 10_200, 0.99, null, null), 10_000)
            .Should().ContainSingle(r => r.Contains("unlogged"));

    [Fact]
    public void Server_disagreement_is_flagged() =>
        _rules.CheckEnd(new OdometerReading(10_300, 10_300, 0.99, 10_800, 0.95), 10_000)
            .Should().ContainSingle(r => r.Contains("server read 10800"));

    [Fact]
    public void Unrealistic_distance_is_flagged() =>
        _rules.CheckEnd(new OdometerReading(11_500, 11_500, 0.99, null, null), 10_000)
            .Should().ContainSingle(r => r.Contains("1000 km limit"));

    [Fact]
    public void Lowest_confidence_ignores_missing_values() =>
        OdometerRules.LowestConfidence(null, 0.9, 0.7, null).Should().Be(0.7);
}

using FleetPilot.Api.Infrastructure.Ocr;
using FluentAssertions;

namespace FleetPilot.Api.Tests.Unit;

public class OdometerParserTests
{
    [Theory]
    [InlineData("045231", 45231)]
    [InlineData("ODO 128904 km", 128904)]
    [InlineData("TRIP A 312.7\nODO 87412", 87412)]
    [InlineData("12:45  24°C\n 053120 km", 53120)]
    [InlineData("km 9 87654", 87654)]
    [InlineData("TRIP 1,204.5 ODO 1204", 1204)]
    [InlineData("0000000", 0)]
    public void Picks_the_odometer_value(string text, int expected) =>
        OdometerParser.Extract(text).Should().Be(expected);

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("no digits here")]
    [InlineData("12.5")]
    [InlineData("123456789")]
    public void Returns_null_when_nothing_usable(string? text) =>
        OdometerParser.Extract(text).Should().BeNull();

    [Fact]
    public void Ties_go_to_the_first_run() => OdometerParser.Extract("1111 2222").Should().Be(1111);
}

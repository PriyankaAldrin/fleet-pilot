using FleetPilot.Api.Common;
using FluentAssertions;

namespace FleetPilot.Api.Tests.Unit;

public class CompanyTimeTests
{
    [Theory]
    [InlineData("Asia/Dubai")]
    [InlineData("Arabian Standard Time")]
    public void Accepts_iana_and_windows_ids(string id) =>
        CompanyTime.Resolve(id).BaseUtcOffset.Should().Be(TimeSpan.FromHours(4));

    [Fact]
    public void Unknown_id_gives_a_clear_error() =>
        FluentActions.Invoking(() => CompanyTime.Resolve("Mars/Olympus"))
            .Should().Throw<InvalidOperationException>().WithMessage("*Company:TimeZone*");
}

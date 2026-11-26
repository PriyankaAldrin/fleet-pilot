using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Options;
using FleetPilot.Api.Services;
using FleetPilot.Api.Tests.Support;
using FluentAssertions;

namespace FleetPilot.Api.Tests.Unit;

public class AuthServiceTests : IDisposable
{
    private readonly TestDb _t = new();

    public void Dispose() => _t.Dispose();

    private AuthService Auth() => new(
        _t.Repo<User>(), _t.Repo<RefreshToken>(), _t.Uow, _t.Hasher,
        new TokenService(Microsoft.Extensions.Options.Options.Create(new JwtOptions { SigningKey = new string('k', 40) }), _t.Clock),
        _t.CurrentUser, _t.Clock);

    [Fact]
    public async Task Login_with_correct_password()
    {
        var d = _t.AddDriver("driver@x.io");

        var res = await Auth().LoginAsync(new LoginRequest(" Driver@X.io ", "Password1"));

        res.User.Id.Should().Be(d.UserId);
        res.User.Role.Should().Be(UserRole.Driver);
        res.AccessToken.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task Login_rejects_wrong_password_and_disabled_accounts()
    {
        var d = _t.AddDriver("driver@x.io");

        var wrong = () => Auth().LoginAsync(new LoginRequest("driver@x.io", "nope"));
        await wrong.Should().ThrowAsync<UnauthorizedException>();

        d.User.IsActive = false;
        await _t.Db.SaveChangesAsync();
        var disabled = () => Auth().LoginAsync(new LoginRequest("driver@x.io", "Password1"));
        await disabled.Should().ThrowAsync<UnauthorizedException>().WithMessage("*disabled*");
    }

    [Fact]
    public async Task Refresh_rotates_and_reuse_ends_all_sessions()
    {
        _t.AddDriver("driver@x.io");
        var login = await Auth().LoginAsync(new LoginRequest("driver@x.io", "Password1"));

        var refreshed = await Auth().RefreshAsync(login.RefreshToken);
        refreshed.RefreshToken.Should().NotBe(login.RefreshToken);

        // Using the old token again is treated as theft.
        var reuse = () => Auth().RefreshAsync(login.RefreshToken);
        await reuse.Should().ThrowAsync<UnauthorizedException>();

        var afterReuse = () => Auth().RefreshAsync(refreshed.RefreshToken);
        await afterReuse.Should().ThrowAsync<UnauthorizedException>();
    }

    [Fact]
    public async Task Expired_refresh_token_is_rejected()
    {
        _t.AddDriver("driver@x.io");
        var login = await Auth().LoginAsync(new LoginRequest("driver@x.io", "Password1"));
        _t.Clock.Advance(TimeSpan.FromDays(31));

        var act = () => Auth().RefreshAsync(login.RefreshToken);

        await act.Should().ThrowAsync<UnauthorizedException>();
    }
}

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using FleetPilot.Api.Data;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Infrastructure.Storage;
using FleetPilot.Api.Services;
using FleetPilot.Api.Tests.Support;
using FluentAssertions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace FleetPilot.Api.Tests.Integration;

/// <summary>Runs the real HTTP pipeline (auth, policies, validation, multipart) against SQLite.</summary>
public sealed class ApiFactory : WebApplicationFactory<Program>
{
    private readonly SqliteConnection _conn = new("DataSource=:memory:");

    public ApiFactory() => _conn.Open();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("Jwt:SigningKey", "integration-test-signing-key-0123456789");
        builder.UseSetting("Serilog:WriteTo:1:Name", "Console");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.AddDbContext<AppDbContext>(o => o.UseSqlite(_conn));
            services.RemoveAll<IPhotoStorage>();
            services.AddSingleton<IPhotoStorage, InMemoryPhotoStorage>();
        });
    }

    public void Seed()
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        if (!db.Database.EnsureCreated()) return;
        var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();
        db.Users.Add(new User { Name = "Root", Email = "root@x.io", PasswordHash = hasher.Hash("Password1"), Role = UserRole.Admin });
        db.SaveChanges();
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        _conn.Dispose();
    }
}

public class ApiTests : IClassFixture<ApiFactory>
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { Converters = { new JsonStringEnumConverter() } };
    private readonly ApiFactory _factory;

    public ApiTests(ApiFactory factory)
    {
        _factory = factory;
        _factory.Seed();
    }

    private async Task<HttpClient> SignIn(string email, string password = "Password1")
    {
        var client = _factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(email, password));
        res.StatusCode.Should().Be(HttpStatusCode.OK, await res.Content.ReadAsStringAsync());
        var auth = await res.Content.ReadFromJsonAsync<AuthResponse>(Json);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth!.AccessToken);
        return client;
    }

    [Fact]
    public async Task Full_driver_day_through_the_api()
    {
        var admin = await SignIn("root@x.io");

        // Validation errors come back as 400 problem details.
        var bad = await admin.PostAsJsonAsync("/api/v1/drivers", new CreateDriverRequest("", "not-an-email", null, "short", "", null));
        bad.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await bad.Content.ReadAsStringAsync()).Should().Contain("errors").And.Contain("email");

        var driverRes = await admin.PostAsJsonAsync("/api/v1/drivers",
            new CreateDriverRequest("Omar K", "omar@x.io", "+971 50 000 0000", "Password1", "DXB-123", new DateOnly(2028, 1, 1)));
        driverRes.StatusCode.Should().Be(HttpStatusCode.Created);
        var vehicleRes = await admin.PostAsJsonAsync("/api/v1/vehicles",
            new CreateVehicleRequest("DXB L 5555", "Mercedes", "S580", 2025, "Black", 12_000));
        vehicleRes.StatusCode.Should().Be(HttpStatusCode.Created);
        var vehicle = await vehicleRes.Content.ReadFromJsonAsync<VehicleDto>(Json);

        var driver = await SignIn("omar@x.io");

        // Drivers cannot use admin endpoints.
        (await driver.GetAsync("/api/v1/drivers")).StatusCode.Should().Be(HttpStatusCode.Forbidden);

        var available = await driver.GetFromJsonAsync<List<VehicleDto>>("/api/v1/vehicles/available", Json);
        available.Should().Contain(v => v.Id == vehicle!.Id);

        (await driver.GetAsync("/api/v1/shifts/active")).StatusCode.Should().Be(HttpStatusCode.NoContent);

        using var start = new MultipartFormDataContent
        {
            { new StringContent(Guid.NewGuid().ToString()), "clientId" },
            { new StringContent(vehicle!.Id.ToString()), "vehicleId" },
            { new StringContent("12010"), "startKm" },
            { new StringContent("12010"), "ocrKm" },
            { new StringContent("0.96"), "ocrConfidence" },
            { Jpeg(), "photo", "start.jpg" },
        };
        var startRes = await driver.PostAsync("/api/v1/shifts/start", start);
        startRes.StatusCode.Should().Be(HttpStatusCode.OK, await startRes.Content.ReadAsStringAsync());
        var shift = await startRes.Content.ReadFromJsonAsync<ShiftDto>(Json);

        var photo = await driver.GetAsync(shift!.StartPhotoUrl);
        photo.StatusCode.Should().Be(HttpStatusCode.OK);

        using var end = new MultipartFormDataContent
        {
            { new StringContent("12000"), "endKm" },
            { Jpeg(), "photo", "end.jpg" },
        };
        var lowEnd = await driver.PostAsync($"/api/v1/shifts/{shift.Id}/end", end);
        lowEnd.StatusCode.Should().Be(HttpStatusCode.UnprocessableEntity);

        using var end2 = new MultipartFormDataContent
        {
            { new StringContent("12190"), "endKm" },
            { new StringContent("12190"), "ocrKm" },
            { new StringContent("0.93"), "ocrConfidence" },
            { Jpeg(), "photo", "end.jpg" },
        };
        var endRes = await driver.PostAsync($"/api/v1/shifts/{shift.Id}/end", end2);
        endRes.StatusCode.Should().Be(HttpStatusCode.OK, await endRes.Content.ReadAsStringAsync());
        (await endRes.Content.ReadFromJsonAsync<ShiftDto>(Json))!.DistanceKm.Should().Be(180);

        var dashboard = await admin.GetFromJsonAsync<DashboardDto>("/api/v1/dashboard", Json);
        dashboard!.ActiveShifts.Should().Be(0);

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var pdf = await admin.GetAsync($"/api/v1/reports/vehicles/{vehicle.Id}?from={today.AddDays(-1):yyyy-MM-dd}&to={today.AddDays(1):yyyy-MM-dd}&format=pdf");
        pdf.StatusCode.Should().Be(HttpStatusCode.OK);
        pdf.Content.Headers.ContentType!.MediaType.Should().Be("application/pdf");

        var audit = await admin.GetFromJsonAsync<JsonElement>("/api/v1/audit-logs", Json);
        audit.GetProperty("totalCount").GetInt32().Should().BeGreaterThan(0);
    }

    [Fact]
    public async Task Anonymous_requests_are_rejected()
    {
        var client = _factory.CreateClient();
        (await client.GetAsync("/api/v1/shifts")).StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    private static ByteArrayContent Jpeg()
    {
        var c = new ByteArrayContent([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
        c.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        return c;
    }
}

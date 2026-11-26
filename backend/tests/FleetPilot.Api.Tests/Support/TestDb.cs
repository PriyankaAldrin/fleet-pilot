using FleetPilot.Api.Common;
using FleetPilot.Api.Data;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Infrastructure.Ocr;
using FleetPilot.Api.Infrastructure.Storage;
using FleetPilot.Api.Options;
using FleetPilot.Api.Repositories;
using FleetPilot.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace FleetPilot.Api.Tests.Support;

public sealed class FakeClock : IClock
{
    public DateTime UtcNow { get; set; } = new(2026, 3, 10, 6, 0, 0, DateTimeKind.Utc);
    public void Advance(TimeSpan by) => UtcNow = UtcNow.Add(by);
}

public sealed class FakeCurrentUser : ICurrentUser
{
    public int? Id { get; set; }
    public string? Email { get; set; }
    public UserRole? Role { get; set; }

    public void SignIn(User u)
    {
        Id = u.Id;
        Email = u.Email;
        Role = u.Role;
    }
}

public sealed class InMemoryPhotoStorage : IPhotoStorage
{
    public Dictionary<string, byte[]> Files { get; } = new();

    public async Task<string> SaveAsync(Stream content, string contentType, string fileName, CancellationToken ct = default)
    {
        using var ms = new MemoryStream();
        await content.CopyToAsync(ms, ct);
        Files[fileName] = ms.ToArray();
        return fileName;
    }

    public Task<StoredPhoto?> OpenAsync(string key, CancellationToken ct = default) =>
        Task.FromResult(Files.TryGetValue(key, out var b) ? new StoredPhoto(new MemoryStream(b), "image/jpeg") : null);
}

public sealed class StubOcr : IOcrService
{
    public OcrResult? Next { get; set; }
    public bool IsEnabled => Next is not null;
    public Task<OcrResult?> ReadOdometerAsync(Stream image, string contentType, CancellationToken ct = default) => Task.FromResult(Next);
}

/// <summary>A fresh SQLite in-memory database with every service wired by hand.</summary>
public sealed class TestDb : IDisposable
{
    private readonly SqliteConnection _conn = new("DataSource=:memory:");

    public FakeClock Clock { get; } = new();
    public FakeCurrentUser CurrentUser { get; } = new();
    public InMemoryPhotoStorage Storage { get; } = new();
    public StubOcr Ocr { get; } = new();
    public IPasswordHasher Hasher { get; } = new FastHasher();
    public AppDbContext Db { get; }
    public OdometerRulesOptions RulesOptions { get; } = new();
    public CompanyOptions Company { get; } = new() { TimeZone = "Asia/Dubai" };

    public TestDb()
    {
        _conn.Open();
        var options = new DbContextOptionsBuilder<AppDbContext>().UseSqlite(_conn).Options;
        Db = new AppDbContext(options, CurrentUser, Clock);
        Db.Database.EnsureCreated();
    }

    public IRepository<T> Repo<T>() where T : class => new Repository<T>(Db);
    public IUnitOfWork Uow => new UnitOfWork(Db);
    public CompanyTime CompanyTime => new(Microsoft.Extensions.Options.Options.Create(Company), Clock);

    public ShiftService Shifts() => new(
        Repo<Shift>(), Repo<Driver>(), Repo<Vehicle>(), Uow, Storage, Ocr,
        new OdometerRules(Microsoft.Extensions.Options.Options.Create(RulesOptions)),
        CurrentUser, Clock, CompanyTime,
        Microsoft.Extensions.Options.Options.Create(new StorageOptions()),
        NullLogger<ShiftService>.Instance);

    public AdminService Admins() => new(Repo<User>(), Uow, Hasher, CurrentUser);
    public DriverService Drivers() => new(Repo<User>(), Repo<Driver>(), Repo<Shift>(), Uow, Hasher);
    public VehicleService Vehicles() => new(Repo<Vehicle>(), Repo<Shift>(), Uow);
    public ReportService Reports() => new(Repo<Shift>(), Repo<Driver>(), Repo<Vehicle>(), CompanyTime);

    public User AddAdmin(string email = "admin@test.local")
    {
        var u = new User { Name = "Admin " + email, Email = email, PasswordHash = Hasher.Hash("Password1"), Role = UserRole.Admin };
        Db.Users.Add(u);
        Db.SaveChanges();
        return u;
    }

    public Driver AddDriver(string email = "driver@test.local", string name = "Sam Driver")
    {
        var d = new Driver
        {
            LicenseNo = "L-" + email,
            User = new User { Name = name, Email = email, PasswordHash = Hasher.Hash("Password1"), Role = UserRole.Driver },
        };
        Db.Drivers.Add(d);
        Db.SaveChanges();
        return d;
    }

    public Vehicle AddVehicle(string plate = "D 12345", int odometer = 10_000)
    {
        var v = new Vehicle { PlateNo = plate, Make = "Cadillac", Model = "Escalade", Year = 2024, CurrentOdometer = odometer };
        Db.Vehicles.Add(v);
        Db.SaveChanges();
        return v;
    }

    public static IFormFile Photo(string name = "odo.jpg")
    {
        var bytes = new byte[] { 0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4 };
        return new FormFile(new MemoryStream(bytes), 0, bytes.Length, "photo", name)
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/jpeg",
        };
    }

    public void Dispose()
    {
        Db.Dispose();
        _conn.Dispose();
    }

    /// <summary>BCrypt at a low work factor keeps tests fast.</summary>
    private sealed class FastHasher : IPasswordHasher
    {
        public string Hash(string password) => BCrypt.Net.BCrypt.HashPassword(password, 4);
        public bool Verify(string password, string hash) => BCrypt.Net.BCrypt.Verify(password, hash);
    }
}

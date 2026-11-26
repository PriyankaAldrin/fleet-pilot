using FleetPilot.Api.Domain;
using FleetPilot.Api.Options;
using FleetPilot.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FleetPilot.Api.Data;

public static class DbInitializer
{
    /// <summary>Applies pending migrations and creates the first admin when there is none.</summary>
    public static async Task InitializeAsync(IServiceProvider services, bool migrate)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("DbInitializer");

        if (migrate)
        {
            logger.LogInformation("Applying database migrations");
            await db.Database.MigrateAsync();
        }

        if (await db.Users.AnyAsync(u => u.Role == UserRole.Admin && !u.IsDeleted)) return;

        var seed = scope.ServiceProvider.GetRequiredService<IOptions<SeedAdminOptions>>().Value;
        if (string.IsNullOrWhiteSpace(seed.Email) || string.IsNullOrWhiteSpace(seed.Password))
        {
            logger.LogWarning("No admin exists and SeedAdmin:Email / SeedAdmin:Password are not set. Nobody can sign in yet.");
            return;
        }

        var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();
        db.Users.Add(new User
        {
            Name = seed.Name,
            Email = seed.Email.Trim().ToLowerInvariant(),
            PasswordHash = hasher.Hash(seed.Password),
            Role = UserRole.Admin,
            IsActive = true,
        });
        await db.SaveChangesAsync();
        logger.LogInformation("Created seed admin {Email}. Change this password after the first sign in.", seed.Email);
    }
}

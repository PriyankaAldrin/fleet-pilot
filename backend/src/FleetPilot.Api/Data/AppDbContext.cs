using System.Text.Json;
using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;

namespace FleetPilot.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options, ICurrentUser currentUser, IClock clock)
    : DbContext(options)
{
    private static readonly HashSet<string> SensitiveProperties = new(StringComparer.OrdinalIgnoreCase)
    {
        nameof(User.PasswordHash),
    };

    public DbSet<User> Users => Set<User>();
    public DbSet<Driver> Drivers => Set<Driver>();
    public DbSet<Vehicle> Vehicles => Set<Vehicle>();
    public DbSet<Shift> Shifts => Set<Shift>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<User>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(150).IsRequired();
            e.Property(x => x.Email).HasMaxLength(256).IsRequired();
            e.Property(x => x.Phone).HasMaxLength(30);
            e.Property(x => x.PasswordHash).HasMaxLength(100).IsRequired();
            e.Property(x => x.Role).HasConversion<string>().HasMaxLength(20);
            // Email is unique among users that are not deleted, so a deleted user's email can be reused.
            e.HasIndex(x => x.Email).IsUnique().HasFilter("[IsDeleted] = 0");
        });

        b.Entity<Driver>(e =>
        {
            e.HasKey(x => x.UserId);
            e.Property(x => x.LicenseNo).HasMaxLength(50).IsRequired();
            e.HasOne(x => x.User).WithOne(x => x.Driver).HasForeignKey<Driver>(x => x.UserId);
        });

        b.Entity<Vehicle>(e =>
        {
            e.Property(x => x.PlateNo).HasMaxLength(20).IsRequired();
            e.Property(x => x.Make).HasMaxLength(50).IsRequired();
            e.Property(x => x.Model).HasMaxLength(50).IsRequired();
            e.Property(x => x.Color).HasMaxLength(30);
            e.HasIndex(x => x.PlateNo).IsUnique().HasFilter("[IsDeleted] = 0");
        });

        b.Entity<Shift>(e =>
        {
            e.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
            e.Property(x => x.StartPhotoUrl).HasMaxLength(500);
            e.Property(x => x.EndPhotoUrl).HasMaxLength(500);
            e.Property(x => x.Notes).HasMaxLength(1000);
            e.Property(x => x.FlagReasons).HasMaxLength(1000);
            e.Property(x => x.ReviewNotes).HasMaxLength(1000);
            e.HasIndex(x => x.ClientId).IsUnique();
            e.HasIndex(x => new { x.DriverId, x.StartTime });
            e.HasIndex(x => new { x.VehicleId, x.StartTime });
            // The database itself guarantees one active shift per driver and per vehicle.
            e.HasIndex(x => x.DriverId).IsUnique().HasFilter("[Status] = 'Active'")
                .HasDatabaseName("IX_Shifts_OneActivePerDriver");
            e.HasIndex(x => x.VehicleId).IsUnique().HasFilter("[Status] = 'Active'")
                .HasDatabaseName("IX_Shifts_OneActivePerVehicle");
            e.HasOne(x => x.Driver).WithMany(x => x.Shifts).HasForeignKey(x => x.DriverId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Vehicle).WithMany(x => x.Shifts).HasForeignKey(x => x.VehicleId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<RefreshToken>(e =>
        {
            e.Property(x => x.TokenHash).HasMaxLength(128).IsRequired();
            e.HasIndex(x => x.TokenHash).IsUnique();
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId);
        });

        b.Entity<AuditLog>(e =>
        {
            e.Property(x => x.Action).HasMaxLength(20);
            e.Property(x => x.EntityType).HasMaxLength(50);
            e.Property(x => x.EntityId).HasMaxLength(50);
            e.Property(x => x.UserEmail).HasMaxLength(256);
            e.HasIndex(x => x.Timestamp);
            e.HasIndex(x => new { x.EntityType, x.EntityId });
        });
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var now = clock.UtcNow;
        ApplyTimestampsAndSoftDelete(now);

        // Only changes made by an admin are audited (driver shift actions are already recorded on the shift).
        var pending = currentUser.IsAdmin ? CaptureAuditEntries() : [];

        var result = await base.SaveChangesAsync(cancellationToken);

        if (pending.Count > 0)
        {
            foreach (var p in pending)
            {
                AuditLogs.Add(new AuditLog
                {
                    UserId = currentUser.Id,
                    UserEmail = currentUser.Email,
                    Action = p.Action,
                    EntityType = p.Entry.Metadata.ClrType.Name,
                    EntityId = KeyOf(p.Entry),
                    Changes = p.Changes is null ? null : JsonSerializer.Serialize(p.Changes),
                    Timestamp = now,
                });
            }
            await base.SaveChangesAsync(cancellationToken);
        }

        return result;
    }

    private void ApplyTimestampsAndSoftDelete(DateTime now)
    {
        foreach (var entry in ChangeTracker.Entries())
        {
            if (entry.State == EntityState.Deleted && entry.Entity is ISoftDeletable soft)
            {
                entry.State = EntityState.Modified;
                soft.IsDeleted = true;
                soft.DeletedAt = now;
            }

            switch (entry.Entity)
            {
                case User u:
                    if (entry.State == EntityState.Added) u.CreatedAt = now;
                    else if (entry.State == EntityState.Modified) u.UpdatedAt = now;
                    break;
                case Vehicle v:
                    if (entry.State == EntityState.Added) v.CreatedAt = now;
                    else if (entry.State == EntityState.Modified) v.UpdatedAt = now;
                    break;
                case Shift s:
                    if (entry.State == EntityState.Added) s.CreatedAt = now;
                    else if (entry.State == EntityState.Modified) s.UpdatedAt = now;
                    break;
            }
        }
    }

    private sealed record PendingAudit(EntityEntry Entry, string Action, Dictionary<string, object?>? Changes);

    private List<PendingAudit> CaptureAuditEntries()
    {
        var list = new List<PendingAudit>();
        foreach (var entry in ChangeTracker.Entries().Where(e => e.Entity is IAuditable))
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    list.Add(new(entry, "Create", entry.Properties
                        .Where(p => !SensitiveProperties.Contains(p.Metadata.Name) && !p.IsTemporary)
                        .ToDictionary(p => p.Metadata.Name, p => p.CurrentValue)));
                    break;
                case EntityState.Modified:
                    var changed = entry.Properties
                        .Where(p => p.IsModified && !Equals(p.OriginalValue, p.CurrentValue))
                        .ToDictionary(
                            p => p.Metadata.Name,
                            p => SensitiveProperties.Contains(p.Metadata.Name)
                                ? (object?)"(changed)"
                                : new { from = p.OriginalValue, to = p.CurrentValue });
                    if (changed.Count == 0) break;
                    var action = entry.Entity is ISoftDeletable { IsDeleted: true } && changed.ContainsKey(nameof(ISoftDeletable.IsDeleted))
                        ? "Delete"
                        : "Update";
                    list.Add(new(entry, action, changed));
                    break;
            }
        }
        return list;
    }

    private static string KeyOf(EntityEntry entry)
    {
        var key = entry.Metadata.FindPrimaryKey();
        if (key is null) return string.Empty;
        return string.Join(",", key.Properties.Select(p => entry.Property(p.Name).CurrentValue?.ToString()));
    }
}

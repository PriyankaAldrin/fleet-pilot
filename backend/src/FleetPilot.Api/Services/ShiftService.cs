using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Infrastructure.Ocr;
using FleetPilot.Api.Infrastructure.Storage;
using FleetPilot.Api.Options;
using FleetPilot.Api.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FleetPilot.Api.Services;

public interface IShiftService
{
    Task<ShiftDto> StartAsync(StartShiftForm form, CancellationToken ct = default);
    Task<ShiftDto> EndAsync(int shiftId, EndShiftForm form, CancellationToken ct = default);
    Task<ShiftDto?> GetActiveForCurrentDriverAsync(CancellationToken ct = default);
    Task<PagedResult<ShiftDto>> ListAsync(ShiftListQuery query, CancellationToken ct = default);
    Task<ShiftDto> GetAsync(int id, CancellationToken ct = default);
    Task<ShiftDto> ReviewAsync(int id, ReviewShiftRequest request, CancellationToken ct = default);
    Task<StoredPhoto> GetPhotoAsync(int id, string which, CancellationToken ct = default);
}

public sealed class ShiftService(
    IRepository<Shift> shifts,
    IRepository<Driver> drivers,
    IRepository<Vehicle> vehicles,
    IUnitOfWork uow,
    IPhotoStorage storage,
    IOcrService ocr,
    OdometerRules rules,
    ICurrentUser currentUser,
    IClock clock,
    CompanyTime companyTime,
    IOptions<StorageOptions> storageOptions,
    ILogger<ShiftService> logger) : IShiftService
{
    private static readonly HashSet<string> AllowedPhotoTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg", "image/jpg", "image/png",
    };

    private IQueryable<Shift> WithDetails => shifts.Query().Include(s => s.Driver).ThenInclude(d => d.User).Include(s => s.Vehicle);

    public async Task<ShiftDto> StartAsync(StartShiftForm form, CancellationToken ct = default)
    {
        var driverId = currentUser.RequireId();

        // Offline sync can send the same request twice; return the shift that was already created.
        var existing = await WithDetails.FirstOrDefaultAsync(s => s.ClientId == form.ClientId, ct);
        if (existing is not null)
        {
            if (existing.DriverId != driverId) throw new ConflictException("This shift id is already in use.");
            return existing.ToDto();
        }

        var driver = await drivers.Query().Include(d => d.User)
            .FirstOrDefaultAsync(d => d.UserId == driverId && !d.User.IsDeleted && d.User.IsActive, ct)
            ?? throw new ForbiddenException("Only active drivers can start shifts.");

        if (await shifts.Query().AnyAsync(s => s.DriverId == driverId && s.Status == ShiftStatus.Active, ct))
            throw new ConflictException("You already have an active shift. End it before starting a new one.");

        var vehicle = await vehicles.Query().FirstOrDefaultAsync(v => v.Id == form.VehicleId && !v.IsDeleted, ct)
            ?? throw NotFoundException.For("Vehicle", form.VehicleId);
        if (!vehicle.IsActive) throw new BusinessRuleException("This vehicle is not in service.");
        if (await shifts.Query().AnyAsync(s => s.VehicleId == vehicle.Id && s.Status == ShiftStatus.Active, ct))
            throw new ConflictException("This vehicle is already in use by another driver.");

        var startTime = ResolveTime(form.RecordedOffline, form.CapturedAt);
        var photo = RequirePhoto(form.Photo);
        var (photoKey, server) = await StoreAndReadAsync(photo, form.ClientId, "start", ct);

        var reading = new OdometerReading(form.StartKm, form.OcrKm, form.OcrConfidence, server?.Km, server?.Confidence);
        var reasons = rules.CheckStart(reading, vehicle.CurrentOdometer);

        var shift = new Shift
        {
            ClientId = form.ClientId,
            DriverId = driverId,
            Driver = driver,
            VehicleId = vehicle.Id,
            Vehicle = vehicle,
            StartTime = startTime,
            StartKm = form.StartKm,
            StartKmOcr = form.OcrKm,
            StartKmServerOcr = server?.Km,
            OcrConfidence = OdometerRules.LowestConfidence(form.OcrConfidence, server?.Confidence),
            KmManuallyEdited = reading.ManuallyEdited,
            StartPhotoUrl = photoKey,
            StartLatitude = form.Latitude,
            StartLongitude = form.Longitude,
            RecordedOffline = form.RecordedOffline,
            Status = ShiftStatus.Active,
            Notes = form.Notes?.Trim(),
        };
        AddFlags(shift, reasons);
        shifts.Add(shift);

        try
        {
            await uow.SaveChangesAsync(ct);
        }
        catch (DbUpdateException ex)
        {
            // The filtered unique indexes catch two starts racing each other.
            logger.LogWarning(ex, "Shift start rejected by a unique index");
            throw new ConflictException("The driver or the vehicle already has an active shift.");
        }

        return shift.ToDto();
    }

    public async Task<ShiftDto> EndAsync(int shiftId, EndShiftForm form, CancellationToken ct = default)
    {
        var userId = currentUser.RequireId();
        var shift = await WithDetails.FirstOrDefaultAsync(s => s.Id == shiftId, ct)
            ?? throw NotFoundException.For("Shift", shiftId);
        if (!currentUser.IsAdmin && shift.DriverId != userId) throw new ForbiddenException("This is not your shift.");

        if (shift.Status == ShiftStatus.Completed)
        {
            // Repeated end from offline sync.
            if (shift.EndKm == form.EndKm) return shift.ToDto();
            throw new ConflictException("This shift has already ended.");
        }

        if (form.EndKm < shift.StartKm)
            throw new BusinessRuleException($"End km ({form.EndKm}) cannot be lower than start km ({shift.StartKm}).");

        var endTime = ResolveTime(form.RecordedOffline, form.CapturedAt);
        if (endTime < shift.StartTime) endTime = shift.StartTime;

        // Admins may close a forgotten shift without a photo; drivers always need one.
        OcrResult? server = null;
        if (form.Photo is not null || !currentUser.IsAdmin)
        {
            var photo = RequirePhoto(form.Photo);
            (shift.EndPhotoUrl, server) = await StoreAndReadAsync(photo, shift.ClientId, "end", ct);
        }

        var reading = new OdometerReading(form.EndKm, form.OcrKm, form.OcrConfidence, server?.Km, server?.Confidence);
        var reasons = rules.CheckEnd(reading, shift.StartKm).ToList();
        if (currentUser.IsAdmin && shift.DriverId != userId)
            reasons.Add($"Ended by admin {currentUser.Email}.");

        shift.EndTime = endTime;
        shift.EndKm = form.EndKm;
        shift.EndKmOcr = form.OcrKm;
        shift.EndKmServerOcr = server?.Km;
        shift.OcrConfidence = OdometerRules.LowestConfidence(shift.OcrConfidence, form.OcrConfidence, server?.Confidence);
        shift.KmManuallyEdited |= reading.ManuallyEdited;
        shift.EndLatitude = form.Latitude;
        shift.EndLongitude = form.Longitude;
        shift.RecordedOffline |= form.RecordedOffline;
        shift.Status = ShiftStatus.Completed;
        if (!string.IsNullOrWhiteSpace(form.Notes))
            shift.Notes = string.IsNullOrEmpty(shift.Notes) ? form.Notes.Trim() : $"{shift.Notes}\n{form.Notes.Trim()}";
        AddFlags(shift, reasons);

        if (form.EndKm > shift.Vehicle.CurrentOdometer) shift.Vehicle.CurrentOdometer = form.EndKm;

        await uow.SaveChangesAsync(ct);
        return shift.ToDto();
    }

    public async Task<ShiftDto?> GetActiveForCurrentDriverAsync(CancellationToken ct = default)
    {
        var id = currentUser.RequireId();
        var shift = await WithDetails.FirstOrDefaultAsync(s => s.DriverId == id && s.Status == ShiftStatus.Active, ct);
        return shift is null ? null : shift.ToDto();
    }

    public async Task<PagedResult<ShiftDto>> ListAsync(ShiftListQuery query, CancellationToken ct = default)
    {
        var q = WithDetails.AsNoTracking();
        // Drivers only ever see their own shifts.
        var driverId = currentUser.IsAdmin ? query.DriverId : currentUser.RequireId();
        if (driverId is { } d) q = q.Where(s => s.DriverId == d);
        if (query.VehicleId is { } v) q = q.Where(s => s.VehicleId == v);
        if (query.Status is { } st) q = q.Where(s => s.Status == st);
        if (query.Flagged is { } f) q = q.Where(s => s.IsFlagged == f);
        if (query.NeedsReview == true) q = q.Where(s => s.IsFlagged && s.ReviewedAt == null);
        if (query.From is { } from) q = q.Where(s => s.StartTime >= companyTime.StartOfDayUtc(from));
        if (query.To is { } to) q = q.Where(s => s.StartTime < companyTime.StartOfDayUtc(to.AddDays(1)));
        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var s = query.Search.Trim();
            q = q.Where(x => x.Driver.User.Name.Contains(s) || x.Vehicle.PlateNo.Contains(s));
        }

        var page = await q.OrderByDescending(s => s.StartTime).ToPagedAsync(query, ct);
        return new(Mappings.ToDtos(page.Items), page.Page, page.PageSize, page.TotalCount);
    }

    public async Task<ShiftDto> GetAsync(int id, CancellationToken ct = default) =>
        (await LoadVisible(id, ct)).ToDto();

    public async Task<ShiftDto> ReviewAsync(int id, ReviewShiftRequest request, CancellationToken ct = default)
    {
        var shift = await WithDetails.FirstOrDefaultAsync(s => s.Id == id, ct) ?? throw NotFoundException.For("Shift", id);

        var startKm = request.StartKm ?? shift.StartKm;
        var endKm = request.EndKm ?? shift.EndKm;
        if (request.EndKm is not null && shift.Status != ShiftStatus.Completed)
            throw new BusinessRuleException("End km can only be corrected after the shift has ended.");
        if (endKm is not null && endKm < startKm)
            throw new BusinessRuleException("End km cannot be lower than start km.");

        shift.StartKm = startKm;
        if (endKm is not null && endKm != shift.EndKm)
        {
            shift.EndKm = endKm;
            // Keep the vehicle's odometer in step when this is its most recent shift.
            var isLatest = !await shifts.Query().AnyAsync(s => s.VehicleId == shift.VehicleId && s.StartTime > shift.StartTime, ct);
            if (isLatest) shift.Vehicle.CurrentOdometer = endKm.Value;
        }
        shift.ReviewedAt = clock.UtcNow;
        shift.ReviewedByUserId = currentUser.Id;
        shift.ReviewNotes = request.ReviewNotes?.Trim();
        await uow.SaveChangesAsync(ct);
        return shift.ToDto();
    }

    public async Task<StoredPhoto> GetPhotoAsync(int id, string which, CancellationToken ct = default)
    {
        var shift = await LoadVisible(id, ct);
        var key = which.ToLowerInvariant() switch
        {
            "start" => shift.StartPhotoUrl,
            "end" => shift.EndPhotoUrl,
            _ => throw new BusinessRuleException("Photo must be 'start' or 'end'."),
        };
        if (key is null) throw new NotFoundException("This shift has no such photo.");
        return await storage.OpenAsync(key, ct) ?? throw new NotFoundException("Photo file is missing.");
    }

    private async Task<Shift> LoadVisible(int id, CancellationToken ct)
    {
        var shift = await WithDetails.FirstOrDefaultAsync(s => s.Id == id, ct) ?? throw NotFoundException.For("Shift", id);
        if (!currentUser.IsAdmin && shift.DriverId != currentUser.Id) throw NotFoundException.For("Shift", id);
        return shift;
    }

    private DateTime ResolveTime(bool recordedOffline, DateTime? capturedAt)
    {
        var now = clock.UtcNow;
        if (!recordedOffline || capturedAt is null) return now; // online: the server's clock is the source of truth

        var captured = capturedAt.Value.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(capturedAt.Value, DateTimeKind.Utc)
            : capturedAt.Value.ToUniversalTime();
        if (captured > now.AddMinutes(5))
            throw new BusinessRuleException("The device clock is ahead of the server. Check the phone's date and time.");
        if (captured < now.AddHours(-rules.Options.MaxOfflineAgeHours))
            throw new BusinessRuleException($"Offline records older than {rules.Options.MaxOfflineAgeHours} hours cannot be synced. Contact your administrator.");
        return captured;
    }

    private IFormFile RequirePhoto(IFormFile? photo)
    {
        if (photo is null || photo.Length == 0) throw new BusinessRuleException("An odometer photo is required.");
        if (photo.Length > storageOptions.Value.MaxPhotoBytes)
            throw new BusinessRuleException($"Photo is larger than {storageOptions.Value.MaxPhotoBytes / 1024 / 1024} MB.");
        if (!AllowedPhotoTypes.Contains(photo.ContentType))
            throw new BusinessRuleException("Photo must be a JPEG or PNG image.");
        return photo;
    }

    private async Task<(string Key, OcrResult? Server)> StoreAndReadAsync(IFormFile photo, Guid clientId, string which, CancellationToken ct)
    {
        var ext = photo.ContentType.Contains("png", StringComparison.OrdinalIgnoreCase) ? "png" : "jpg";
        string key;
        await using (var s = photo.OpenReadStream())
            key = await storage.SaveAsync(s, photo.ContentType, $"{clientId:N}-{which}.{ext}", ct);

        if (!ocr.IsEnabled) return (key, null);
        try
        {
            await using var s = photo.OpenReadStream();
            return (key, await ocr.ReadOdometerAsync(s, photo.ContentType, ct));
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            // Server OCR is a second opinion; never block a shift because it failed.
            logger.LogWarning(ex, "Server OCR failed for shift {ClientId} ({Which})", clientId, which);
            return (key, null);
        }
    }

    private static void AddFlags(Shift shift, IEnumerable<string> reasons)
    {
        var all = (shift.FlagReasons ?? string.Empty)
            .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Concat(reasons.Select(r => r.Replace(';', ',')))
            .Distinct()
            .ToList();
        if (all.Count == 0) return;
        shift.IsFlagged = true;
        shift.FlagReasons = Truncate(string.Join("; ", all), 1000);
        // New issues on an already-reviewed shift need a fresh review.
        shift.ReviewedAt = null;
    }

    private static string Truncate(string s, int max) => s.Length <= max ? s : s[..(max - 1)] + "…";
}

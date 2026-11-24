namespace FleetPilot.Api.Options;

public sealed class JwtOptions
{
    public const string Section = "Jwt";
    public string Issuer { get; set; } = "FleetPilot";
    public string Audience { get; set; } = "FleetPilot.App";
    /// <summary>At least 32 characters. Never commit the real value.</summary>
    public string SigningKey { get; set; } = string.Empty;
    public int AccessTokenMinutes { get; set; } = 30;
    public int RefreshTokenDays { get; set; } = 30;
}

public sealed class OdometerRulesOptions
{
    public const string Section = "OdometerRules";
    /// <summary>Flag a reading when OCR confidence (0..1) is below this.</summary>
    public double MinOcrConfidence { get; set; } = 0.80;
    /// <summary>Flag a shift whose distance is above this.</summary>
    public int MaxKmPerShift { get; set; } = 1000;
    /// <summary>Flag a start reading that is this many km above the vehicle's last known odometer (unlogged driving).</summary>
    public int MaxGapBetweenShiftsKm { get; set; } = 50;
    /// <summary>Flag when the server OCR and the confirmed value differ by more than this.</summary>
    public int ServerOcrToleranceKm { get; set; } = 0;
    /// <summary>Oldest offline timestamp the server accepts, in hours.</summary>
    public int MaxOfflineAgeHours { get; set; } = 72;
}

public sealed class StorageOptions
{
    public const string Section = "Storage";
    /// <summary>"Local" or "AzureBlob".</summary>
    public string Provider { get; set; } = "Local";
    public string LocalPath { get; set; } = "App_Data/photos";
    public string? AzureConnectionString { get; set; }
    public string AzureContainer { get; set; } = "odometer-photos";
    public long MaxPhotoBytes { get; set; } = 8 * 1024 * 1024;
}

public sealed class OcrOptions
{
    public const string Section = "Ocr";
    /// <summary>"None" or "Azure".</summary>
    public string Provider { get; set; } = "None";
    public string? AzureEndpoint { get; set; }
    public string? AzureKey { get; set; }
}

public sealed class CompanyOptions
{
    public const string Section = "Company";
    public string Name { get; set; } = "Fleet Pilot";
    /// <summary>Time zone used for "today" and for report date ranges, e.g. "Asia/Dubai" or "America/Toronto".</summary>
    public string TimeZone { get; set; } = "UTC";
}

public sealed class SeedAdminOptions
{
    public const string Section = "SeedAdmin";
    public string Name { get; set; } = "Administrator";
    public string? Email { get; set; }
    public string? Password { get; set; }
}

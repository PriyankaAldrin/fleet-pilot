using System.Security.Claims;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using FleetPilot.Api.Common;
using FleetPilot.Api.Data;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Infrastructure.Ocr;
using FleetPilot.Api.Infrastructure.Reports;
using FleetPilot.Api.Infrastructure.Storage;
using FleetPilot.Api.Middleware;
using FleetPilot.Api.Options;
using FleetPilot.Api.Repositories;
using FleetPilot.Api.Services;
using FluentValidation;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, cfg) => cfg.ReadFrom.Configuration(ctx.Configuration).Enrich.FromLogContext());

// ---------- options ----------
var config = builder.Configuration;
builder.Services.Configure<JwtOptions>(config.GetSection(JwtOptions.Section));
builder.Services.Configure<OdometerRulesOptions>(config.GetSection(OdometerRulesOptions.Section));
builder.Services.Configure<StorageOptions>(config.GetSection(StorageOptions.Section));
builder.Services.Configure<OcrOptions>(config.GetSection(OcrOptions.Section));
builder.Services.Configure<CompanyOptions>(config.GetSection(CompanyOptions.Section));
builder.Services.Configure<SeedAdminOptions>(config.GetSection(SeedAdminOptions.Section));

var jwt = config.GetSection(JwtOptions.Section).Get<JwtOptions>() ?? new JwtOptions();
if (jwt.SigningKey.Length < 32)
    throw new InvalidOperationException("Jwt:SigningKey must be at least 32 characters. Set it in appsettings or an environment variable.");

// ---------- data ----------
builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseSqlServer(config.GetConnectionString("Default"), sql => sql.EnableRetryOnFailure()));
builder.Services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();

// ---------- core services ----------
builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton<IClock, SystemClock>();
builder.Services.AddSingleton<CompanyTime>();
builder.Services.AddScoped<ICurrentUser, HttpCurrentUser>();
builder.Services.AddSingleton<IPasswordHasher, BCryptPasswordHasher>();
builder.Services.AddSingleton<ITokenService, TokenService>();
builder.Services.AddSingleton<OdometerRules>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IAdminService, AdminService>();
builder.Services.AddScoped<IDriverService, DriverService>();
builder.Services.AddScoped<IVehicleService, VehicleService>();
builder.Services.AddScoped<IShiftService, ShiftService>();
builder.Services.AddScoped<IDashboardService, DashboardService>();
builder.Services.AddScoped<IReportService, ReportService>();
builder.Services.AddScoped<IAuditService, AuditService>();
builder.Services.AddSingleton<IReportExporter, ReportExporter>();
builder.Services.AddValidatorsFromAssemblyContaining<Program>();
QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;

// Photo storage: Local or AzureBlob
var storage = config.GetSection(StorageOptions.Section).Get<StorageOptions>() ?? new StorageOptions();
if (storage.Provider.Equals("AzureBlob", StringComparison.OrdinalIgnoreCase))
    builder.Services.AddSingleton<IPhotoStorage, AzureBlobPhotoStorage>();
else
    builder.Services.AddSingleton<IPhotoStorage, LocalPhotoStorage>();

// Server side OCR: None or Azure
var ocr = config.GetSection(OcrOptions.Section).Get<OcrOptions>() ?? new OcrOptions();
if (ocr.Provider.Equals("Azure", StringComparison.OrdinalIgnoreCase))
    builder.Services.AddHttpClient<IOcrService, AzureVisionOcrService>(c => c.Timeout = TimeSpan.FromSeconds(15));
else
    builder.Services.AddSingleton<IOcrService, NoOcrService>();

// ---------- web ----------
builder.Services.AddControllers(o =>
    {
        o.Filters.Add<ValidationFilter>();
        o.Filters.Add<AppExceptionFilter>();
    })
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SigningKey)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30),
            NameClaimType = ClaimTypes.Name,
            RoleClaimType = ClaimTypes.Role,
        };
    });
builder.Services.AddAuthorizationBuilder()
    .AddPolicy(Policies.Admin, p => p.RequireRole(nameof(UserRole.Admin)))
    .AddPolicy(Policies.Driver, p => p.RequireRole(nameof(UserRole.Driver)));

builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddPolicy("login", http => RateLimitPartition.GetFixedWindowLimiter(
        http.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1) }));
});

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
{
    var origins = config.GetSection("Cors:Origins").Get<string[]>() ?? [];
    if (origins.Length > 0) p.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod();
}));

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Fleet Pilot API", Version = "v1" });
    var scheme = new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" },
    };
    c.AddSecurityDefinition("Bearer", scheme);
    c.AddSecurityRequirement(new OpenApiSecurityRequirement { [scheme] = [] });
    c.MapType<DateOnly>(() => new OpenApiSchema { Type = "string", Format = "date" });
});

builder.Services.AddHealthChecks().AddDbContextCheck<AppDbContext>();

var app = builder.Build();

app.UseExceptionHandler();
app.UseSerilogRequestLogging();

if (app.Environment.IsDevelopment() || config.GetValue<bool>("Swagger:Enabled"))
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health");

if (!app.Environment.IsEnvironment("Testing"))
    await DbInitializer.InitializeAsync(app.Services, config.GetValue("Database:MigrateOnStartup", true));

app.Run();

public partial class Program;

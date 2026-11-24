using FleetPilot.Api.Common;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Infrastructure.Reports;
using FleetPilot.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FleetPilot.Api.Controllers;

[ApiController]
[Route("api/v1/dashboard")]
[Authorize(Policy = Policies.Admin)]
public sealed class DashboardController(IDashboardService dashboard) : ControllerBase
{
    [HttpGet]
    public Task<DashboardDto> Get(CancellationToken ct) => dashboard.GetAsync(ct);
}

[ApiController]
[Route("api/v1/audit-logs")]
[Authorize(Policy = Policies.Admin)]
public sealed class AuditLogsController(IAuditService audit) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<AuditLogDto>> List([FromQuery] AuditLogQuery query, CancellationToken ct) => audit.ListAsync(query, ct);
}

/// <summary>
/// Reports. Dates are calendar days in the company time zone, both ends inclusive.
/// Add <c>?format=pdf</c> or <c>?format=xlsx</c> to download a file instead of JSON.
/// </summary>
[ApiController]
[Route("api/v1/reports")]
[Authorize(Policy = Policies.Admin)]
public sealed class ReportsController(IReportService reports, IReportExporter exporter) : ControllerBase
{
    [HttpGet("drivers")]
    public async Task<IActionResult> Drivers([FromQuery] ReportQuery query, [FromQuery] string? format, CancellationToken ct) =>
        Respond(await reports.DriverSummaryAsync(query, ct), format);

    [HttpGet("drivers/{id:int}")]
    public async Task<IActionResult> Driver(int id, [FromQuery] ReportQuery query, [FromQuery] string? format, CancellationToken ct) =>
        Respond(await reports.DriverReportAsync(id, query, ct), format);

    [HttpGet("vehicles")]
    public async Task<IActionResult> Vehicles([FromQuery] ReportQuery query, [FromQuery] string? format, CancellationToken ct) =>
        Respond(await reports.VehicleSummaryAsync(query, ct), format);

    [HttpGet("vehicles/{id:int}")]
    public async Task<IActionResult> Vehicle(int id, [FromQuery] ReportQuery query, [FromQuery] string? format, CancellationToken ct) =>
        Respond(await reports.VehicleReportAsync(id, query, ct), format);

    private IActionResult Respond(EntityReport r, string? format) => format?.ToLowerInvariant() switch
    {
        null or "" or "json" => Ok(r),
        "pdf" => FileOf(exporter.ToPdf(r)),
        "xlsx" or "excel" => FileOf(exporter.ToExcel(r)),
        _ => throw new BusinessRuleException("format must be json, pdf or xlsx."),
    };

    private IActionResult Respond(SummaryReport r, string? format) => format?.ToLowerInvariant() switch
    {
        null or "" or "json" => Ok(r),
        "pdf" => FileOf(exporter.ToPdf(r)),
        "xlsx" or "excel" => FileOf(exporter.ToExcel(r)),
        _ => throw new BusinessRuleException("format must be json, pdf or xlsx."),
    };

    private FileContentResult FileOf(ExportedFile f) => File(f.Content, f.ContentType, f.FileName);
}

using FleetPilot.Api.Common;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FleetPilot.Api.Controllers;

[ApiController]
[Route("api/v1/shifts")]
[Authorize]
public sealed class ShiftsController(IShiftService shifts) : ControllerBase
{
    /// <summary>Admins see every shift; drivers see only their own.</summary>
    [HttpGet]
    public Task<PagedResult<ShiftDto>> List([FromQuery] ShiftListQuery query, CancellationToken ct) => shifts.ListAsync(query, ct);

    /// <summary>The signed-in driver's active shift, or 204 when there is none.</summary>
    [HttpGet("active")]
    [Authorize(Policy = Policies.Driver)]
    public async Task<ActionResult<ShiftDto>> Active(CancellationToken ct) =>
        await shifts.GetActiveForCurrentDriverAsync(ct) is { } s ? Ok(s) : NoContent();

    [HttpGet("{id:int}")]
    public Task<ShiftDto> Get(int id, CancellationToken ct) => shifts.GetAsync(id, ct);

    [HttpPost("start")]
    [Authorize(Policy = Policies.Driver)]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(12 * 1024 * 1024)]
    public Task<ShiftDto> Start([FromForm] StartShiftForm form, CancellationToken ct) => shifts.StartAsync(form, ct);

    [HttpPost("{id:int}/end")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(12 * 1024 * 1024)]
    public Task<ShiftDto> End(int id, [FromForm] EndShiftForm form, CancellationToken ct) => shifts.EndAsync(id, form, ct);

    [HttpPut("{id:int}/review")]
    [Authorize(Policy = Policies.Admin)]
    public Task<ShiftDto> Review(int id, ReviewShiftRequest request, CancellationToken ct) => shifts.ReviewAsync(id, request, ct);

    /// <summary>Odometer photo. <paramref name="which"/> is "start" or "end".</summary>
    [HttpGet("{id:int}/photos/{which}")]
    public async Task<IActionResult> Photo(int id, string which, CancellationToken ct)
    {
        var photo = await shifts.GetPhotoAsync(id, which, ct);
        Response.Headers.CacheControl = "private, max-age=86400";
        return File(photo.Content, photo.ContentType);
    }
}

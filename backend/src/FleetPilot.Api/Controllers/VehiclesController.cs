using FleetPilot.Api.Common;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FleetPilot.Api.Controllers;

[ApiController]
[Route("api/v1/vehicles")]
[Authorize(Policy = Policies.Admin)]
public sealed class VehiclesController(IVehicleService vehicles) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<VehicleDto>> List([FromQuery] VehicleListQuery query, CancellationToken ct) => vehicles.ListAsync(query, ct);

    [HttpGet("{id:int}")]
    public Task<VehicleDto> Get(int id, CancellationToken ct) => vehicles.GetAsync(id, ct);

    [HttpPost]
    public async Task<ActionResult<VehicleDto>> Create(CreateVehicleRequest request, CancellationToken ct)
    {
        var created = await vehicles.CreateAsync(request, ct);
        return CreatedAtAction(nameof(Get), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    public Task<VehicleDto> Update(int id, UpdateVehicleRequest request, CancellationToken ct) => vehicles.UpdateAsync(id, request, ct);

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        await vehicles.DeleteAsync(id, ct);
        return NoContent();
    }
}

/// <summary>Open to every signed-in user (drivers pick a car from this list).</summary>
[ApiController]
[Route("api/v1/vehicles/available")]
[Authorize]
public sealed class AvailableVehiclesController(IVehicleService vehicles) : ControllerBase
{
    /// <summary>Active vehicles that are not in an active shift.</summary>
    [HttpGet]
    public Task<IReadOnlyList<VehicleDto>> Get(CancellationToken ct) => vehicles.AvailableAsync(ct);
}

using FleetPilot.Api.Common;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FleetPilot.Api.Controllers;

[ApiController]
[Route("api/v1/drivers")]
[Authorize(Policy = Policies.Admin)]
public sealed class DriversController(IDriverService drivers) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<DriverDto>> List([FromQuery] UserListQuery query, CancellationToken ct) => drivers.ListAsync(query, ct);

    [HttpGet("{id:int}")]
    public Task<DriverDto> Get(int id, CancellationToken ct) => drivers.GetAsync(id, ct);

    [HttpPost]
    public async Task<ActionResult<DriverDto>> Create(CreateDriverRequest request, CancellationToken ct)
    {
        var created = await drivers.CreateAsync(request, ct);
        return CreatedAtAction(nameof(Get), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    public Task<DriverDto> Update(int id, UpdateDriverRequest request, CancellationToken ct) => drivers.UpdateAsync(id, request, ct);

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        await drivers.DeleteAsync(id, ct);
        return NoContent();
    }
}

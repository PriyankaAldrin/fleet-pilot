using FleetPilot.Api.Common;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FleetPilot.Api.Controllers;

[ApiController]
[Route("api/v1/admins")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminsController(IAdminService admins) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<AdminDto>> List([FromQuery] UserListQuery query, CancellationToken ct) => admins.ListAsync(query, ct);

    [HttpGet("{id:int}")]
    public Task<AdminDto> Get(int id, CancellationToken ct) => admins.GetAsync(id, ct);

    [HttpPost]
    public async Task<ActionResult<AdminDto>> Create(CreateAdminRequest request, CancellationToken ct)
    {
        var created = await admins.CreateAsync(request, ct);
        return CreatedAtAction(nameof(Get), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    public Task<AdminDto> Update(int id, UpdateAdminRequest request, CancellationToken ct) => admins.UpdateAsync(id, request, ct);

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        await admins.DeleteAsync(id, ct);
        return NoContent();
    }
}

using FleetPilot.Api.Common;
using FleetPilot.Api.Domain;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Repositories;

namespace FleetPilot.Api.Services;

public interface IAuditService
{
    Task<PagedResult<AuditLogDto>> ListAsync(AuditLogQuery query, CancellationToken ct = default);
}

public sealed class AuditService(IRepository<AuditLog> logs) : IAuditService
{
    public Task<PagedResult<AuditLogDto>> ListAsync(AuditLogQuery query, CancellationToken ct = default)
    {
        var q = logs.Query();
        if (!string.IsNullOrWhiteSpace(query.EntityType)) q = q.Where(l => l.EntityType == query.EntityType);
        if (!string.IsNullOrWhiteSpace(query.EntityId)) q = q.Where(l => l.EntityId == query.EntityId);
        if (!string.IsNullOrWhiteSpace(query.Search))
            q = q.Where(l => l.UserEmail != null && l.UserEmail.Contains(query.Search));
        return q.OrderByDescending(l => l.Id).Select(Mappings.AuditProjection).ToPagedAsync(query, ct);
    }
}

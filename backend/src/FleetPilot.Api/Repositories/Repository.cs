using FleetPilot.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace FleetPilot.Api.Repositories;

/// <summary>
/// Thin generic repository over EF Core. Services compose queries through <see cref="Query"/>
/// and commit through <see cref="IUnitOfWork"/>.
/// </summary>
public interface IRepository<T> where T : class
{
    IQueryable<T> Query();
    ValueTask<T?> FindAsync(params object[] keys);
    void Add(T entity);
    void Remove(T entity);
}

public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}

public sealed class Repository<T>(AppDbContext db) : IRepository<T> where T : class
{
    public IQueryable<T> Query() => db.Set<T>();
    public ValueTask<T?> FindAsync(params object[] keys) => db.Set<T>().FindAsync(keys);
    public void Add(T entity) => db.Set<T>().Add(entity);
    public void Remove(T entity) => db.Set<T>().Remove(entity);
}

public sealed class UnitOfWork(AppDbContext db) : IUnitOfWork
{
    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}

public static class QueryableExtensions
{
    public static async Task<FleetPilot.Api.Common.PagedResult<T>> ToPagedAsync<T>(
        this IQueryable<T> query, FleetPilot.Api.Common.PageQuery page, CancellationToken ct = default)
    {
        var total = await query.CountAsync(ct);
        var items = await query.Skip((page.SafePage - 1) * page.SafePageSize).Take(page.SafePageSize).ToListAsync(ct);
        return new(items, page.SafePage, page.SafePageSize, total);
    }
}

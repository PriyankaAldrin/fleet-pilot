using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using FleetPilot.Api.Options;
using Microsoft.Extensions.Options;

namespace FleetPilot.Api.Infrastructure.Storage;

public record StoredPhoto(Stream Content, string ContentType);

/// <summary>Stores odometer photos. The key returned by <see cref="SaveAsync"/> is kept on the shift.</summary>
public interface IPhotoStorage
{
    Task<string> SaveAsync(Stream content, string contentType, string fileName, CancellationToken ct = default);
    Task<StoredPhoto?> OpenAsync(string key, CancellationToken ct = default);
}

public sealed class LocalPhotoStorage : IPhotoStorage
{
    private readonly string _root;

    public LocalPhotoStorage(IOptions<StorageOptions> options, IWebHostEnvironment env)
    {
        var path = options.Value.LocalPath;
        _root = Path.GetFullPath(Path.IsPathRooted(path) ? path : Path.Combine(env.ContentRootPath, path));
        Directory.CreateDirectory(_root);
    }

    public async Task<string> SaveAsync(Stream content, string contentType, string fileName, CancellationToken ct = default)
    {
        var key = $"{DateTime.UtcNow:yyyy/MM}/{fileName}";
        var full = Resolve(key);
        Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        await using var file = File.Create(full);
        await content.CopyToAsync(file, ct);
        return key;
    }

    public Task<StoredPhoto?> OpenAsync(string key, CancellationToken ct = default)
    {
        var full = Resolve(key);
        if (!File.Exists(full)) return Task.FromResult<StoredPhoto?>(null);
        var type = full.EndsWith(".png", StringComparison.OrdinalIgnoreCase) ? "image/png" : "image/jpeg";
        return Task.FromResult<StoredPhoto?>(new StoredPhoto(File.OpenRead(full), type));
    }

    private string Resolve(string key)
    {
        var full = Path.GetFullPath(Path.Combine(_root, key));
        if (!full.StartsWith(_root, StringComparison.Ordinal)) throw new InvalidOperationException("Invalid photo key.");
        return full;
    }
}

public sealed class AzureBlobPhotoStorage(IOptions<StorageOptions> options) : IPhotoStorage
{
    private readonly BlobContainerClient _container = new(options.Value.AzureConnectionString, options.Value.AzureContainer);
    private bool _ensured;

    public async Task<string> SaveAsync(Stream content, string contentType, string fileName, CancellationToken ct = default)
    {
        if (!_ensured)
        {
            await _container.CreateIfNotExistsAsync(PublicAccessType.None, cancellationToken: ct);
            _ensured = true;
        }
        var key = $"{DateTime.UtcNow:yyyy/MM}/{fileName}";
        await _container.GetBlobClient(key).UploadAsync(content,
            new BlobUploadOptions { HttpHeaders = new BlobHttpHeaders { ContentType = contentType } }, ct);
        return key;
    }

    public async Task<StoredPhoto?> OpenAsync(string key, CancellationToken ct = default)
    {
        var blob = _container.GetBlobClient(key);
        if (!await blob.ExistsAsync(ct)) return null;
        var result = await blob.DownloadStreamingAsync(cancellationToken: ct);
        return new StoredPhoto(result.Value.Content, result.Value.Details.ContentType ?? "image/jpeg");
    }
}

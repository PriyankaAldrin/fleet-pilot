using System.Net.Http.Headers;
using System.Text.Json;
using FleetPilot.Api.Options;
using Microsoft.Extensions.Options;

namespace FleetPilot.Api.Infrastructure.Ocr;

public record OcrResult(int? Km, double? Confidence, string RawText);

/// <summary>Reads an odometer value from a photo on the server. Swap the implementation in Program.cs.</summary>
public interface IOcrService
{
    bool IsEnabled { get; }
    Task<OcrResult?> ReadOdometerAsync(Stream image, string contentType, CancellationToken ct = default);
}

/// <summary>Used when no server OCR is configured. The device reading is then the only automatic reading.</summary>
public sealed class NoOcrService : IOcrService
{
    public bool IsEnabled => false;
    public Task<OcrResult?> ReadOdometerAsync(Stream image, string contentType, CancellationToken ct = default) =>
        Task.FromResult<OcrResult?>(null);
}

/// <summary>Azure AI Vision Image Analysis 4.0 "read" feature, called over REST.</summary>
public sealed class AzureVisionOcrService(HttpClient http, IOptions<OcrOptions> options, ILogger<AzureVisionOcrService> logger)
    : IOcrService
{
    private readonly OcrOptions _opt = options.Value;

    public bool IsEnabled => true;

    public async Task<OcrResult?> ReadOdometerAsync(Stream image, string contentType, CancellationToken ct = default)
    {
        var url = $"{_opt.AzureEndpoint!.TrimEnd('/')}/computervision/imageanalysis:analyze?api-version=2024-02-01&features=read";
        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.Add("Ocp-Apim-Subscription-Key", _opt.AzureKey);
        request.Content = new StreamContent(image);
        request.Content.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");

        using var response = await http.SendAsync(request, ct);
        if (!response.IsSuccessStatusCode)
        {
            logger.LogWarning("Azure OCR returned {Status}: {Body}", response.StatusCode, await response.Content.ReadAsStringAsync(ct));
            return null;
        }

        using var doc = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(ct), cancellationToken: ct);
        return Parse(doc.RootElement);
    }

    /// <summary>Parses the Image Analysis response. Public for tests.</summary>
    public static OcrResult Parse(JsonElement root)
    {
        var lines = new List<string>();
        var words = new List<(string Text, double Confidence)>();
        if (root.TryGetProperty("readResult", out var read) && read.TryGetProperty("blocks", out var blocks))
        {
            foreach (var block in blocks.EnumerateArray())
            foreach (var line in block.GetProperty("lines").EnumerateArray())
            {
                lines.Add(line.GetProperty("text").GetString() ?? string.Empty);
                if (!line.TryGetProperty("words", out var ws)) continue;
                foreach (var w in ws.EnumerateArray())
                    words.Add((w.GetProperty("text").GetString() ?? string.Empty,
                        w.TryGetProperty("confidence", out var c) ? c.GetDouble() : 0));
            }
        }

        var raw = string.Join('\n', lines);
        var km = OdometerParser.Extract(raw);
        double? confidence = null;
        if (km is not null)
        {
            var kmText = km.Value.ToString();
            var matching = words.Where(w => w.Text.Contains(kmText)).Select(w => w.Confidence).ToList();
            confidence = matching.Count > 0 ? matching.Max() : null;
        }
        return new OcrResult(km, confidence, raw);
    }
}

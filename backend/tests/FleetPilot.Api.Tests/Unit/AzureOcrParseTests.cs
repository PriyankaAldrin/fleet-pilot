using System.Text.Json;
using FleetPilot.Api.Infrastructure.Ocr;
using FluentAssertions;

namespace FleetPilot.Api.Tests.Unit;

public class AzureOcrParseTests
{
    [Fact]
    public void Reads_value_and_confidence_from_image_analysis_response()
    {
        const string json = """
        {
          "readResult": {
            "blocks": [
              { "lines": [
                { "text": "TRIP 231.4", "words": [ { "text": "TRIP", "confidence": 0.99 }, { "text": "231.4", "confidence": 0.95 } ] },
                { "text": "ODO 084512 km", "words": [ { "text": "ODO", "confidence": 0.98 }, { "text": "084512", "confidence": 0.91 }, { "text": "km", "confidence": 0.99 } ] }
              ] }
            ]
          }
        }
        """;
        var result = AzureVisionOcrService.Parse(JsonDocument.Parse(json).RootElement);
        result.Km.Should().Be(84512);
        result.Confidence.Should().Be(0.91);
    }

    [Fact]
    public void Empty_response_gives_no_value() =>
        AzureVisionOcrService.Parse(JsonDocument.Parse("{}").RootElement).Km.Should().BeNull();
}

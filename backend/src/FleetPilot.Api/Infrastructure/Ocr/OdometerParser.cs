using System.Text.RegularExpressions;

namespace FleetPilot.Api.Infrastructure.Ocr;

/// <summary>
/// Picks the odometer value out of raw OCR text. The same rules are implemented in the Flutter app
/// (lib/features/odometer/odometer_parser.dart) so the device and the server agree.
/// </summary>
public static partial class OdometerParser
{
    /// <summary>Odometers in service have at most 7 digits (9,999,999 km).</summary>
    public const int MaxDigits = 7;

    [GeneratedRegex(@"\d+")]
    private static partial Regex DigitRun();

    /// <summary>
    /// Returns the longest run of digits that is not the integer part of a decimal number
    /// (trip meters such as "123.4" are skipped). Ties go to the first run found.
    /// </summary>
    public static int? Extract(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;
        string? best = null;
        foreach (Match m in DigitRun().Matches(text))
        {
            var end = m.Index + m.Length;
            var isDecimalPart = m.Index >= 2 && (text[m.Index - 1] is '.' or ',') && char.IsDigit(text[m.Index - 2]);
            var isIntegerPartOfDecimal = end + 1 < text.Length && (text[end] is '.' or ',') && char.IsDigit(text[end + 1]);
            if (isDecimalPart || isIntegerPartOfDecimal) continue;

            var digits = m.Value.TrimStart('0');
            if (digits.Length == 0) digits = "0";
            if (digits.Length > MaxDigits) continue;
            if (best is null || digits.Length > best.Length) best = digits;
        }
        return best is null ? null : int.Parse(best);
    }
}

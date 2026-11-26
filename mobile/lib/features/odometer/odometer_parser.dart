/// Picks the odometer value out of raw OCR text.
///
/// Same rules as the server (backend/src/FleetPilot.Api/Infrastructure/Ocr/OdometerParser.cs):
/// the longest run of digits wins, trip meters with a decimal point ("123.4") are skipped,
/// runs longer than 7 digits are ignored, and ties go to the first run.
class OdometerParser {
  OdometerParser._();

  static const maxDigits = 7;
  static final _digits = RegExp(r'\d+');

  static int? extract(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    String? best;
    for (final m in _digits.allMatches(text)) {
      final start = m.start;
      final end = m.end;
      final isDecimalPart = start >= 2 && _isSep(text[start - 1]) && _isDigit(text[start - 2]);
      final isIntegerPartOfDecimal = end + 1 < text.length && _isSep(text[end]) && _isDigit(text[end + 1]);
      if (isDecimalPart || isIntegerPartOfDecimal) continue;

      var digits = m.group(0)!.replaceFirst(RegExp(r'^0+'), '');
      if (digits.isEmpty) digits = '0';
      if (digits.length > maxDigits) continue;
      if (best == null || digits.length > best.length) best = digits;
    }
    return best == null ? null : int.parse(best);
  }

  static bool _isSep(String c) => c == '.' || c == ',';
  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'odometer_parser.dart';

class OdometerOcrResult {
  const OdometerOcrResult(this.km, this.confidence, this.rawText);

  final int? km;

  /// 0..1 when the platform reports it (ML Kit gives line confidence on Android), otherwise null.
  final double? confidence;
  final String rawText;
}

/// Reads the odometer number from a photo on the device with Google ML Kit (works offline).
class OdometerReader {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OdometerOcrResult> read(String imagePath) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    final lines = result.blocks.expand((b) => b.lines).toList();
    final raw = lines.map((l) => l.text).join('\n');
    final km = OdometerParser.extract(raw);
    double? confidence;
    if (km != null) {
      final kmText = km.toString();
      final matching = lines.where((l) => l.text.contains(kmText)).map((l) => l.confidence).whereType<double>();
      if (matching.isNotEmpty) confidence = matching.reduce((a, b) => a > b ? a : b);
    }
    return OdometerOcrResult(km, confidence, raw);
  }

  Future<void> dispose() => _recognizer.close();
}

final odometerReaderProvider = Provider<OdometerReader>((ref) {
  final reader = OdometerReader();
  ref.onDispose(reader.dispose);
  return reader;
});

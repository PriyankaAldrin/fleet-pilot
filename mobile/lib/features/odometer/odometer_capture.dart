/// What the driver confirmed on the odometer screen.
class OdometerCapture {
  OdometerCapture({
    required this.photoPath,
    required this.confirmedKm,
    required this.ocrKm,
    required this.ocrConfidence,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.notes,
  });

  final String photoPath;
  final int confirmedKm;
  final int? ocrKm;
  final double? ocrConfidence;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final String? notes;

  bool get edited => ocrKm != confirmedKm;

  Map<String, dynamic> toJson() => {
        'photoPath': photoPath,
        'confirmedKm': confirmedKm,
        'ocrKm': ocrKm,
        'ocrConfidence': ocrConfidence,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes,
      };

  factory OdometerCapture.fromJson(Map<String, dynamic> j) => OdometerCapture(
        photoPath: j['photoPath'] as String,
        confirmedKm: j['confirmedKm'] as int,
        ocrKm: j['ocrKm'] as int?,
        ocrConfidence: (j['ocrConfidence'] as num?)?.toDouble(),
        capturedAt: DateTime.parse(j['capturedAt'] as String),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        notes: j['notes'] as String?,
      );

  OdometerCapture withPhoto(String path) => OdometerCapture(
        photoPath: path,
        confirmedKm: confirmedKm,
        ocrKm: ocrKm,
        ocrConfidence: ocrConfidence,
        capturedAt: capturedAt,
        latitude: latitude,
        longitude: longitude,
        notes: notes,
      );
}

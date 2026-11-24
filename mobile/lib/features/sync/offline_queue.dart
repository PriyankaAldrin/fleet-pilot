import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../odometer/odometer_capture.dart';

enum PendingKind { start, end }

/// A shift start or end that could not reach the server yet.
class PendingOp {
  PendingOp({
    required this.id,
    required this.kind,
    required this.clientId,
    required this.capture,
    this.vehicleId,
    this.serverShiftId,
    this.error,
  });

  final String id;
  final PendingKind kind;

  /// Client id of the shift this op belongs to.
  final String clientId;
  final OdometerCapture capture;
  final int? vehicleId;
  int? serverShiftId;

  /// Set when the server refused the op. It stays in the queue until the driver dismisses it.
  String? error;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'clientId': clientId,
        'capture': capture.toJson(),
        'vehicleId': vehicleId,
        'serverShiftId': serverShiftId,
        'error': error,
      };

  factory PendingOp.fromJson(Map<String, dynamic> j) => PendingOp(
        id: j['id'] as String,
        kind: PendingKind.values.byName(j['kind'] as String),
        clientId: j['clientId'] as String,
        capture: OdometerCapture.fromJson(j['capture'] as Map<String, dynamic>),
        vehicleId: j['vehicleId'] as int?,
        serverShiftId: j['serverShiftId'] as int?,
        error: j['error'] as String?,
      );
}

/// Ordered queue saved as JSON in the app's documents folder. Photos are copied next to it
/// so they survive the camera's temporary files being cleaned up.
class OfflineQueue {
  OfflineQueue({Future<Directory> Function()? baseDir}) : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;
  List<PendingOp>? _ops;

  Future<Directory> _dir() async {
    final d = Directory('${(await _baseDir()).path}/sync');
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  Future<File> _file() async => File('${(await _dir()).path}/queue.json');

  Future<List<PendingOp>> all() async {
    if (_ops != null) return List.unmodifiable(_ops!);
    final f = await _file();
    if (!f.existsSync()) return List.unmodifiable(_ops = []);
    try {
      final list = jsonDecode(await f.readAsString()) as List;
      _ops = list.map((e) => PendingOp.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _ops = [];
    }
    return List.unmodifiable(_ops!);
  }

  Future<void> add(PendingOp op) async {
    await all();
    final dir = await _dir();
    final kept = await File(op.capture.photoPath).copy('${dir.path}/${op.id}.jpg');
    _ops!.add(PendingOp(
      id: op.id,
      kind: op.kind,
      clientId: op.clientId,
      capture: op.capture.withPhoto(kept.path),
      vehicleId: op.vehicleId,
      serverShiftId: op.serverShiftId,
    ));
    await _save();
  }

  Future<void> update(PendingOp op) async {
    await all();
    final i = _ops!.indexWhere((o) => o.id == op.id);
    if (i >= 0) _ops![i] = op;
    await _save();
  }

  Future<void> remove(PendingOp op) async {
    await all();
    _ops!.removeWhere((o) => o.id == op.id);
    final photo = File(op.capture.photoPath);
    if (photo.existsSync()) await photo.delete();
    await _save();
  }

  Future<void> _save() async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(_ops!.map((o) => o.toJson()).toList()));
    await tmp.rename(f.path);
  }
}

import 'dart:io';

import 'package:fleet_pilot/features/odometer/odometer_capture.dart';
import 'package:fleet_pilot/features/sync/offline_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('queue_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  OdometerCapture capture(String photo) => OdometerCapture(
        photoPath: photo,
        confirmedKm: 1000,
        ocrKm: 1000,
        ocrConfidence: 0.9,
        capturedAt: DateTime.utc(2026, 3, 1, 5),
      );

  test('ops survive a restart and keep their own copy of the photo', () async {
    final photo = File('${tmp.path}/camera.jpg')..writeAsBytesSync([1, 2, 3]);
    final q1 = OfflineQueue(baseDir: () async => tmp);
    await q1.add(PendingOp(id: 'op1', kind: PendingKind.start, clientId: 'c1', capture: capture(photo.path), vehicleId: 4));
    await q1.add(PendingOp(id: 'op2', kind: PendingKind.end, clientId: 'c1', capture: capture(photo.path)));
    photo.deleteSync(); // the camera's temp file goes away

    final q2 = OfflineQueue(baseDir: () async => tmp);
    final ops = await q2.all();
    expect(ops.map((o) => o.id), ['op1', 'op2']);
    expect(ops.first.vehicleId, 4);
    expect(File(ops.first.capture.photoPath).existsSync(), isTrue);

    await q2.remove(ops.first);
    expect((await OfflineQueue(baseDir: () async => tmp).all()).map((o) => o.id), ['op2']);
    expect(File(ops.first.capture.photoPath).existsSync(), isFalse);
  });

  test('errors are saved with the op', () async {
    final photo = File('${tmp.path}/camera.jpg')..writeAsBytesSync([1]);
    final q = OfflineQueue(baseDir: () async => tmp);
    await q.add(PendingOp(id: 'op1', kind: PendingKind.start, clientId: 'c1', capture: capture(photo.path), vehicleId: 1));
    final op = (await q.all()).single..error = 'Vehicle in use';
    await q.update(op);

    expect((await OfflineQueue(baseDir: () async => tmp).all()).single.error, 'Vehicle in use');
  });
}

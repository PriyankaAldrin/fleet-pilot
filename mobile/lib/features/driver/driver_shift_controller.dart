import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../odometer/odometer_capture.dart';
import '../sync/offline_queue.dart';

/// The driver's current shift as the app knows it, from the server or recorded offline.
class CurrentShift {
  CurrentShift({
    required this.clientId,
    this.serverId,
    required this.vehicleId,
    required this.vehiclePlate,
    required this.vehicleDescription,
    required this.startTime,
    required this.startKm,
    this.isFlagged = false,
  });

  final String clientId;
  final int? serverId;
  final int vehicleId;
  final String vehiclePlate;
  final String vehicleDescription;
  final DateTime startTime;
  final int startKm;
  final bool isFlagged;

  factory CurrentShift.fromShift(Shift s) => CurrentShift(
        clientId: s.clientId,
        serverId: s.id,
        vehicleId: s.vehicleId,
        vehiclePlate: s.vehiclePlateNo,
        vehicleDescription: s.vehicleDescription,
        startTime: s.startTime,
        startKm: s.startKm,
        isFlagged: s.isFlagged,
      );

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'serverId': serverId,
        'vehicleId': vehicleId,
        'vehiclePlate': vehiclePlate,
        'vehicleDescription': vehicleDescription,
        'startTime': startTime.toUtc().toIso8601String(),
        'startKm': startKm,
        'isFlagged': isFlagged,
      };

  factory CurrentShift.fromJson(Map<String, dynamic> j) => CurrentShift(
        clientId: j['clientId'] as String,
        serverId: j['serverId'] as int?,
        vehicleId: j['vehicleId'] as int,
        vehiclePlate: j['vehiclePlate'] as String,
        vehicleDescription: j['vehicleDescription'] as String,
        startTime: DateTime.parse(j['startTime'] as String).toLocal(),
        startKm: j['startKm'] as int,
        isFlagged: j['isFlagged'] as bool? ?? false,
      );
}

class DriverShiftState {
  const DriverShiftState({this.current, this.pending = const [], this.offline = false, this.lastShift});

  final CurrentShift? current;
  final List<PendingOp> pending;
  final bool offline;

  /// The shift that was just completed, to show a summary.
  final Shift? lastShift;

  PendingOp? get failed => pending.where((p) => p.error != null).firstOrNull;
}

/// Starts and ends shifts. When the network is down the action is queued and synced later.
class DriverShiftController extends AsyncNotifier<DriverShiftState> {
  static const _kCurrent = 'current_shift';
  final _queue = OfflineQueue();
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  bool _syncing = false;

  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<DriverShiftState> build() async {
    _connectivity ??= Connectivity().onConnectivityChanged.listen((r) {
      if (!r.contains(ConnectivityResult.none)) refresh();
    });
    ref.onDispose(() => _connectivity?.cancel());

    final cached = await _loadCurrent();
    final pending = await _queue.all();
    // Show what we have right away, then talk to the server.
    Future.microtask(refresh);
    return DriverShiftState(current: cached, pending: pending);
  }

  /// Sends queued actions, then reloads the active shift from the server.
  Future<void> refresh() async {
    final before = state.value ?? const DriverShiftState();
    try {
      await _sync();
      final pending = await _queue.all();
      CurrentShift? current = before.current;
      if (pending.isEmpty) {
        final res = await _api.call((d) => d.get<Map<String, dynamic>>('/shifts/active'));
        current = res.statusCode == 204 || res.data == null ? null : CurrentShift.fromShift(Shift.fromJson(res.data!));
        await _saveCurrent(current);
      }
      state = AsyncData(DriverShiftState(current: current, pending: pending, lastShift: before.lastShift));
    } on ApiException catch (e) {
      // Keep showing what we know; the next refresh tries again.
      state = AsyncData(DriverShiftState(
        current: before.current,
        pending: await _queue.all(),
        offline: e.isNetwork,
        lastShift: before.lastShift,
      ));
    }
  }

  Future<void> startShift(Vehicle vehicle, OdometerCapture capture) async {
    final clientId = const Uuid().v4();
    final local = CurrentShift(
      clientId: clientId,
      vehicleId: vehicle.id,
      vehiclePlate: vehicle.plateNo,
      vehicleDescription: vehicle.description,
      startTime: capture.capturedAt,
      startKm: capture.confirmedKm,
    );
    try {
      final shift = await _postStart(clientId, vehicle.id, capture, offline: false);
      await _setCurrent(CurrentShift.fromShift(shift), offline: false);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      await _queue.add(PendingOp(
        id: const Uuid().v4(),
        kind: PendingKind.start,
        clientId: clientId,
        capture: capture,
        vehicleId: vehicle.id,
      ));
      await _setCurrent(local, offline: true);
    }
  }

  Future<void> endShift(OdometerCapture capture) async {
    final current = state.value?.current;
    if (current == null) return;
    final hasPending = (await _queue.all()).isNotEmpty;
    if (current.serverId != null && !hasPending) {
      try {
        final shift = await _postEnd(current.serverId!, capture, offline: false);
        await _saveCurrent(null);
        state = AsyncData(DriverShiftState(lastShift: shift));
        return;
      } on ApiException catch (e) {
        if (!e.isNetwork) rethrow;
      }
    }
    await _queue.add(PendingOp(
      id: const Uuid().v4(),
      kind: PendingKind.end,
      clientId: current.clientId,
      capture: capture,
      serverShiftId: current.serverId,
    ));
    await _saveCurrent(null);
    state = AsyncData(DriverShiftState(pending: await _queue.all(), offline: true));
  }

  /// Drops a queued action the server refused (for example, the vehicle was taken by someone else).
  Future<void> discard(PendingOp op) async {
    final all = await _queue.all();
    // Ending a shift whose start was refused makes no sense either.
    for (final o in all.where((o) => o.clientId == op.clientId)) {
      await _queue.remove(o);
    }
    final current = state.value?.current;
    if (current?.clientId == op.clientId && current?.serverId == null) await _saveCurrent(null);
    await refresh();
  }

  Future<void> _sync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final ids = <String, int>{};
      for (final op in await _queue.all()) {
        if (op.error != null) break; // wait for the driver to look at it
        try {
          if (op.kind == PendingKind.start) {
            final shift = await _postStart(op.clientId, op.vehicleId!, op.capture, offline: true);
            ids[op.clientId] = shift.id;
            final current = state.value?.current;
            if (current?.clientId == op.clientId) await _saveCurrent(CurrentShift.fromShift(shift));
          } else {
            final id = op.serverShiftId ?? ids[op.clientId] ?? await _findServerId(op.clientId);
            if (id == null) break;
            await _postEnd(id, op.capture, offline: true);
          }
          await _queue.remove(op);
        } on ApiException catch (e) {
          if (e.isNetwork || !e.isRejected) rethrow;
          op.error = e.message;
          await _queue.update(op);
          break;
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<int?> _findServerId(String clientId) async {
    final res = await _api.call((d) => d.get<Map<String, dynamic>>('/shifts', queryParameters: {'pageSize': 20}));
    final page = Paged.fromJson(res.data!, Shift.fromJson);
    return page.items.where((s) => s.clientId == clientId).firstOrNull?.id;
  }

  Future<Shift> _postStart(String clientId, int vehicleId, OdometerCapture c, {required bool offline}) async {
    final res = await _api.multipart<Map<String, dynamic>>('/shifts/start', () async {
      return FormData.fromMap({
        'clientId': clientId,
        'vehicleId': vehicleId,
        ..._fields(c, 'startKm', offline),
        'photo': await MultipartFile.fromFile(c.photoPath, filename: 'start.jpg', contentType: DioMediaType('image', 'jpeg')),
      });
    });
    return Shift.fromJson(res.data!);
  }

  Future<Shift> _postEnd(int shiftId, OdometerCapture c, {required bool offline}) async {
    final res = await _api.multipart<Map<String, dynamic>>('/shifts/$shiftId/end', () async {
      return FormData.fromMap({
        ..._fields(c, 'endKm', offline),
        'photo': await MultipartFile.fromFile(c.photoPath, filename: 'end.jpg', contentType: DioMediaType('image', 'jpeg')),
      });
    });
    return Shift.fromJson(res.data!);
  }

  Map<String, dynamic> _fields(OdometerCapture c, String kmField, bool offline) => {
        kmField: c.confirmedKm,
        if (c.ocrKm != null) 'ocrKm': c.ocrKm,
        if (c.ocrConfidence != null) 'ocrConfidence': c.ocrConfidence,
        if (c.latitude != null) 'latitude': c.latitude,
        if (c.longitude != null) 'longitude': c.longitude,
        if (c.notes != null && c.notes!.isNotEmpty) 'notes': c.notes,
        'recordedOffline': offline,
        if (offline) 'capturedAt': c.capturedAt.toUtc().toIso8601String(),
      };

  Future<void> _setCurrent(CurrentShift current, {required bool offline}) async {
    await _saveCurrent(current);
    state = AsyncData(DriverShiftState(current: current, pending: await _queue.all(), offline: offline));
  }

  Future<CurrentShift?> _loadCurrent() async {
    final raw = (await SharedPreferences.getInstance()).getString(_kCurrent);
    return raw == null ? null : CurrentShift.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _saveCurrent(CurrentShift? c) async {
    final prefs = await SharedPreferences.getInstance();
    if (c == null) {
      await prefs.remove(_kCurrent);
    } else {
      await prefs.setString(_kCurrent, jsonEncode(c.toJson()));
    }
  }
}

final driverShiftProvider = AsyncNotifierProvider<DriverShiftController, DriverShiftState>(DriverShiftController.new);

final availableVehiclesProvider = FutureProvider.autoDispose<List<Vehicle>>((ref) async {
  final res = await ref.read(apiClientProvider).call((d) => d.get<List<dynamic>>('/vehicles/available'));
  return res.data!.map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList();
});

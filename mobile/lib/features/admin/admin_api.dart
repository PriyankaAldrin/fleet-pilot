import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

enum ExportFormat { pdf, xlsx }

class ExportedReport {
  ExportedReport(this.bytes, this.fileName);
  final Uint8List bytes;
  final String fileName;
}

/// Admin endpoints: CRUD, dashboard, shift review and reports.
class AdminApi {
  AdminApi(this._api);

  final ApiClient _api;
  static final _day = DateFormat('yyyy-MM-dd');

  Future<Paged<T>> _page<T>(String path, int page, String search, T Function(Map<String, dynamic>) item,
      [Map<String, dynamic> extra = const {}]) async {
    final res = await _api.call((d) => d.get<Map<String, dynamic>>(path, queryParameters: {
          'page': page,
          'pageSize': 20,
          if (search.isNotEmpty) 'search': search,
          ...extra,
        }));
    return Paged.fromJson(res.data!, item);
  }

  Future<Map<String, dynamic>> _send(String method, String path, [Object? body]) async {
    final res = await _api.call((d) => d.request<Map<String, dynamic>>(path, data: body, options: Options(method: method)));
    return res.data ?? const {};
  }

  // Dashboard
  Future<Dashboard> dashboard() async => Dashboard.fromJson(await _send('GET', '/dashboard'));

  // Admins
  Future<Paged<Admin>> admins(int page, String search) => _page('/admins', page, search, Admin.fromJson);
  Future<void> saveAdmin(int? id, Map<String, dynamic> body) =>
      id == null ? _send('POST', '/admins', body) : _send('PUT', '/admins/$id', body);
  Future<void> deleteAdmin(int id) => _send('DELETE', '/admins/$id');

  // Drivers
  Future<Paged<Driver>> drivers(int page, String search) => _page('/drivers', page, search, Driver.fromJson);
  Future<void> saveDriver(int? id, Map<String, dynamic> body) =>
      id == null ? _send('POST', '/drivers', body) : _send('PUT', '/drivers/$id', body);
  Future<void> deleteDriver(int id) => _send('DELETE', '/drivers/$id');

  // Vehicles
  Future<Paged<Vehicle>> vehicles(int page, String search) => _page('/vehicles', page, search, Vehicle.fromJson);
  Future<void> saveVehicle(int? id, Map<String, dynamic> body) =>
      id == null ? _send('POST', '/vehicles', body) : _send('PUT', '/vehicles/$id', body);
  Future<void> deleteVehicle(int id) => _send('DELETE', '/vehicles/$id');

  // Shifts
  Future<Paged<Shift>> shifts(int page, String search, {String? status, bool? needsReview}) =>
      _page('/shifts', page, search, Shift.fromJson, {
        'status': ?status,
        if (needsReview == true) 'needsReview': true,
      });
  Future<Shift> shift(int id) async => Shift.fromJson(await _send('GET', '/shifts/$id'));
  Future<Shift> review(int id, {int? startKm, int? endKm, String? notes}) async => Shift.fromJson(
      await _send('PUT', '/shifts/$id/review', {'startKm': startKm, 'endKm': endKm, 'reviewNotes': notes}));

  /// Closes a shift the driver forgot to end. No photo is needed for admins.
  Future<Shift> endForDriver(int id, int endKm) async {
    final res = await _api.multipart<Map<String, dynamic>>('/shifts/$id/end', () async => FormData.fromMap({'endKm': endKm}));
    return Shift.fromJson(res.data!);
  }

  // Reports
  Map<String, dynamic> _range(DateTime from, DateTime to) => {'from': _day.format(from), 'to': _day.format(to)};

  Future<EntityReport> driverReport(int id, DateTime from, DateTime to) async =>
      EntityReport.fromJson(await _get('/reports/drivers/$id', _range(from, to)));
  Future<EntityReport> vehicleReport(int id, DateTime from, DateTime to) async =>
      EntityReport.fromJson(await _get('/reports/vehicles/$id', _range(from, to)));
  Future<SummaryReport> driverSummary(DateTime from, DateTime to) async =>
      SummaryReport.fromJson(await _get('/reports/drivers', _range(from, to)));
  Future<SummaryReport> vehicleSummary(DateTime from, DateTime to) async =>
      SummaryReport.fromJson(await _get('/reports/vehicles', _range(from, to)));

  Future<Map<String, dynamic>> _get(String path, Map<String, dynamic> q) async =>
      (await _api.call((d) => d.get<Map<String, dynamic>>(path, queryParameters: q))).data!;

  /// [path] is one of the report paths above, e.g. "/reports/drivers/5".
  Future<ExportedReport> export(String path, DateTime from, DateTime to, ExportFormat format) async {
    final res = await _api.call((d) => d.get<List<int>>(path,
        queryParameters: {..._range(from, to), 'format': format.name},
        options: Options(responseType: ResponseType.bytes)));
    final disposition = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    return ExportedReport(Uint8List.fromList(res.data!), match?.group(1) ?? 'report.${format.name}');
  }
}

final adminApiProvider = Provider<AdminApi>((ref) => AdminApi(ref.watch(apiClientProvider)));

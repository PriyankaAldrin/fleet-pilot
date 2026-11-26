import 'package:fleet_pilot/core/api_client.dart';
import 'package:fleet_pilot/core/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Shift parses the API JSON', () {
    final s = Shift.fromJson({
      'id': 7,
      'clientId': 'a1b2',
      'driverId': 3,
      'driverName': 'Omar',
      'vehicleId': 2,
      'vehiclePlateNo': 'DXB L 5555',
      'vehicleDescription': 'Mercedes S580',
      'startTime': '2026-03-01T05:00:00Z',
      'endTime': '2026-03-01T13:30:00Z',
      'startKm': 12010,
      'endKm': 12190,
      'distanceKm': 180,
      'durationHours': 8.5,
      'startPhotoUrl': '/api/v1/shifts/7/photos/start',
      'endPhotoUrl': null,
      'startKmOcr': 12010,
      'endKmOcr': 12199,
      'ocrConfidence': 0.91,
      'kmManuallyEdited': true,
      'recordedOffline': false,
      'status': 'Completed',
      'isFlagged': true,
      'flagReasons': ['End: driver changed the reading from 12199 to 12190 km.'],
      'reviewedAt': null,
    });
    expect(s.status, ShiftStatus.completed);
    expect(s.needsReview, isTrue);
    expect(s.durationHours, 8.5);
    expect(s.startTime.isUtc, isFalse);
    expect(s.startTime.toUtc(), DateTime.utc(2026, 3, 1, 5));
    expect(s.flagReasons, hasLength(1));
  });

  test('Paged knows when more pages exist', () {
    final p = Paged.fromJson({'items': [], 'page': 1, 'pageSize': 20, 'totalCount': 41}, (j) => j);
    expect(p.hasMore, isTrue);
  });

  test('ApiException reads problem details and field errors', () {
    final req = RequestOptions(path: '/drivers');
    final e = ApiException.from(DioException(
      requestOptions: req,
      response: Response(requestOptions: req, statusCode: 400, data: {
        'title': 'Validation failed',
        'detail': 'One or more fields are invalid.',
        'errors': {
          'email': ['Email is not valid.'],
        },
      }),
    ));
    expect(e.statusCode, 400);
    expect(e.isRejected, isTrue);
    expect(e.isNetwork, isFalse);
    expect(e.fieldErrors['email'], ['Email is not valid.']);
    expect(e.message, 'Email is not valid.');
  });

  test('A request that never got an answer is a network error', () {
    final e = ApiException.from(DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError));
    expect(e.isNetwork, isTrue);
  });
}

import 'package:fleet_pilot/features/odometer/odometer_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Same cases as backend/tests/FleetPilot.Api.Tests/Unit/OdometerParserTests.cs so both sides agree.
void main() {
  group('OdometerParser.extract', () {
    final cases = <String, int>{
      '045231': 45231,
      'ODO 128904 km': 128904,
      'TRIP A 312.7\nODO 87412': 87412,
      '12:45  24°C\n 053120 km': 53120,
      'km 9 87654': 87654,
      'TRIP 1,204.5 ODO 1204': 1204,
      '0000000': 0,
      '1111 2222': 1111,
    };
    cases.forEach((text, expected) {
      test('"${text.replaceAll('\n', r'\n')}" -> $expected', () => expect(OdometerParser.extract(text), expected));
    });

    for (final text in [null, '', 'no digits here', '12.5', '123456789']) {
      test('"$text" -> null', () => expect(OdometerParser.extract(text), isNull));
    }
  });
}

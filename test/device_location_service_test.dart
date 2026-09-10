import 'package:chichago/services/device_location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats captured coordinates clearly', () {
    const location = CapturedLocation(latitude: 33.8966, longitude: 35.4823);

    expect(location.label, '33.896600, 35.482300');
  });
}

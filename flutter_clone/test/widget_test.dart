import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_clone/src/data.dart';

void main() {
  test('seed data covers the cloned screens', () {
    expect(settingsMenuItems.length, 7);
    expect(notificationItems.length, 4);
    expect(routeItems.length, greaterThanOrEqualTo(8));
    expect(offerCards.length, 3);
  });
}

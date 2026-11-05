import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenrev_mobile/core/services/visit_tracker.dart';

void main() {
  test('visitor ID is random, valid and stable per install', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await VisitTracker.visitorId();
    expect(a, matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(await VisitTracker.visitorId(), a);
    SharedPreferences.setMockInitialValues({});
    expect(await VisitTracker.visitorId(), isNot(a));
  });

  test('days are counted in Lagos time', () {
    expect(VisitTracker.lagosDay(DateTime.utc(2026, 11, 4, 23, 30)), '2026-11-05');
    expect(VisitTracker.lagosDay(DateTime.utc(2026, 11, 4, 22, 59)), '2026-11-04');
  });
}

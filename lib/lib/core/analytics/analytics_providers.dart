import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_analytics.dart';

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>((ref) {
  return FirebaseAnalytics.instance;
});

final appAnalyticsProvider = Provider<AppAnalytics>((ref) {
  return AppAnalytics(ref.watch(firebaseAnalyticsProvider));
});

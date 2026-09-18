import 'package:firebase_analytics/firebase_analytics.dart';

class AppAnalytics {
  AppAnalytics(this._analytics);

  final FirebaseAnalytics _analytics;

  Future<void> logLogin() => _analytics.logLogin(loginMethod: 'email');

  Future<void> logSignUp() => _analytics.logSignUp(signUpMethod: 'email');

  Future<void> logStudyItemCreated(String type) {
    return _analytics.logEvent(
      name: 'study_item_created',
      parameters: {'type': type},
    );
  }

  Future<void> logStudyItemCompleted(String type) {
    return _analytics.logEvent(
      name: 'study_item_completed',
      parameters: {'type': type},
    );
  }

  Future<void> logScreen(String screenName) {
    return _analytics.logScreenView(screenName: screenName);
  }
}

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/notification_repository.dart';

class NotificationService {
  NotificationService({
    required NotificationRepository repository,
    required FirebaseMessaging messaging,
  }) : _repository = repository,
       _messaging = messaging;

  final NotificationRepository _repository;
  final FirebaseMessaging _messaging;

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _activeUid;

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  Future<bool> enableForUser(String uid) async {
    _activeUid = uid;

    await _repository.setAutoInitEnabled(true);
    await _repository.setForegroundPresentationOptions();

    final permission = await _repository.requestPermission();
    final allowed =
        permission.authorizationStatus == AuthorizationStatus.authorized ||
        permission.authorizationStatus == AuthorizationStatus.provisional;

    if (!allowed) return false;

    // Apple platformlarında FCM token istemeden önce APNs token hazır olmalı.
    // APNs gecikirse ana uygulama akışını kırmadan kısa süre bekliyoruz.
    await _repository.waitForApnsToken();
    final token = await _repository.getToken();
    if (token != null && token.isNotEmpty) {
      await _repository.registerCurrentInstallation(uid: uid, token: token);
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _repository.onTokenRefresh.listen((newToken) {
      final currentUid = _activeUid;
      if (currentUid == null || currentUid.isEmpty || newToken.isEmpty) return;
      _repository
          .registerCurrentInstallation(uid: currentUid, token: newToken)
          .catchError((_) {});
    });

    return true;
  }

  Future<void> disableForUser(String uid) async {
    _activeUid = null;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    await _repository.unregisterCurrentInstallation(uid);
    try {
      await _messaging.deleteToken();
    } catch (_) {
      // Token silinemese bile sunucu kaydı kaldırıldığı için logout devam eder.
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
  }
}

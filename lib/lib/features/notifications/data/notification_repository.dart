import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/notification_preferences.dart';

class NotificationRepository {
  NotificationRepository({
    required FirebaseFirestore firestore,
    required FirebaseMessaging messaging,
    required FirebaseInstallations installations,
  }) : _firestore = firestore,
       _messaging = messaging,
       _installations = installations;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final FirebaseInstallations _installations;

  DocumentReference<Map<String, dynamic>> _preferencesRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('notifications');
  }

  CollectionReference<Map<String, dynamic>> _devicesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('devices');
  }

  Stream<NotificationPreferences> watchPreferences(String uid) {
    if (uid.trim().isEmpty) {
      return Stream.value(const NotificationPreferences());
    }

    return _preferencesRef(uid).snapshots().map(
      (snapshot) => NotificationPreferences.fromMap(snapshot.data()),
    );
  }

  Future<void> savePreferences(
    String uid,
    NotificationPreferences preferences,
  ) async {
    if (uid.trim().isEmpty) {
      throw StateError('Bildirim tercihleri için aktif kullanıcı bulunamadı.');
    }

    await _preferencesRef(uid).set({
      ...preferences.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
  }

  Future<void> setAutoInitEnabled(bool enabled) =>
      _messaging.setAutoInitEnabled(enabled);

  Future<void> setForegroundPresentationOptions() =>
      _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

  Future<String?> getToken() => _messaging.getToken();

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  bool get _isApplePlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<String?> getApnsToken() async {
    if (!_isApplePlatform) return null;
    return _messaging.getAPNSToken();
  }

  Future<String?> waitForApnsToken({
    int attempts = 10,
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    if (!_isApplePlatform) return null;

    for (var i = 0; i < attempts; i++) {
      final token = await getApnsToken();
      if (token != null && token.isNotEmpty) return token;
      await Future<void>.delayed(delay);
    }
    return null;
  }

  Future<String> getInstallationId() => _installations.getId();

  Future<void> registerCurrentInstallation({
    required String uid,
    required String token,
  }) async {
    if (uid.trim().isEmpty || token.trim().isEmpty) return;

    final installationId = await getInstallationId();
    final apnsToken = await getApnsToken();

    final ref = _devicesRef(uid).doc(installationId);
    final existing = await ref.get();

    final data = <String, dynamic>{
      'installationId': installationId,
      'fcmToken': token,
      'apnsToken': apnsToken,
      'platform': defaultTargetPlatform.name,
      'notificationsEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> unregisterCurrentInstallation(String uid) async {
    if (uid.trim().isEmpty) return;

    final installationId = await getInstallationId();
    await _devicesRef(uid).doc(installationId).delete();
  }
}

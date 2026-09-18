import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../application/notification_service.dart';
import '../../application/local_notification_service.dart';
import '../../data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    messaging: ref.watch(firebaseMessagingProvider),
    installations: ref.watch(firebaseInstallationsProvider),
  );
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    repository: ref.watch(notificationRepositoryProvider),
    messaging: ref.watch(firebaseMessagingProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final foregroundNotificationProvider = StreamProvider<RemoteMessage>((ref) {
  return ref.watch(notificationServiceProvider).foregroundMessages;
});

final localNotificationPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>(
      (ref) => FlutterLocalNotificationsPlugin(),
    );

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return LocalNotificationService(ref.watch(localNotificationPluginProvider));
});

import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService(this._plugin);

  static const generalChannelId = 'calis360_general';
  static const reminderChannelId = 'calis360_reminders';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  Future<void> initialize({
    required void Function(Map<String, dynamic> data) onTap,
  }) async {
    if (_initialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;

        if (payload == null || payload.trim().isEmpty) {
          return;
        }

        try {
          final decoded = jsonDecode(payload);

          if (decoded is Map) {
            onTap(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // Bozuk payload navigasyonu etkilememeli.
        }
      },
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        generalChannelId,
        'Genel bildirimler',
        description: 'Çalış 360 genel bildirimleri',
        importance: Importance.high,
      ),
    );

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        reminderChannelId,
        'Çalışma hatırlatıcıları',
        description: 'Ders, sınav, hedef ve çalışma hatırlatıcıları',
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  Future<void> showRemoteMessage({
    required int id,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final type = data['type']?.toString() ?? '';

    final isReminder = type.contains('reminder') || type == 'weekly_report';

    final channelId = isReminder ? reminderChannelId : generalChannelId;

    final channelName = isReminder
        ? 'Çalışma hatırlatıcıları'
        : 'Genel bildirimler';

    final channelDescription = isReminder
        ? 'Ders, sınav, hedef ve çalışma hatırlatıcıları'
        : 'Çalış 360 genel bildirimleri';

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: jsonEncode(data),
    );
  }
}

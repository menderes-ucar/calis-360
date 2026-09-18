import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/notification_providers.dart';

class NotificationBootstrap extends ConsumerStatefulWidget {
  const NotificationBootstrap({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<NotificationBootstrap> createState() =>
      _NotificationBootstrapState();
}

class _NotificationBootstrapState extends ConsumerState<NotificationBootstrap> {
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _registeredUid;
  bool _listenersStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _initializeLocalNotifications();
      _startMessageListeners();
      await _syncCurrentUser(ref.read(currentFirebaseUserProvider));
    });
  }

  Future<void> _initializeLocalNotifications() async {
    await ref
        .read(localNotificationServiceProvider)
        .initialize(
          onTap: (data) {
            if (!mounted) return;
            _openData(data);
          },
        );
  }

  void _startMessageListeners() {
    if (_listenersStarted) return;
    _listenersStarted = true;
    final service = ref.read(notificationServiceProvider);

    _foregroundSubscription = service.foregroundMessages.listen((
      message,
    ) async {
      if (!mounted) return;
      final title = message.notification?.title ?? 'Çalış 360';
      final body = message.notification?.body ?? 'Yeni bir bildirimin var.';
      final id =
          (message.messageId ??
                  '${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}')
              .hashCode &
          0x7fffffff;
      await ref.read(localNotificationServiceProvider).showRemoteMessage(
        id: id,
        title: title,
        body: body,
        data: message.data,
      );
    });

    _openedSubscription = service.openedMessages.listen(
      (message) => _openData(message.data),
    );
    service.getInitialMessage().then((message) {
      if (!mounted || message == null) return;
      _openData(message.data);
    });
  }

  Future<void> _syncCurrentUser(User? user) async {
    if (!mounted) return;
    if (user == null) {
      _registeredUid = null;
      return;
    }
    if (_registeredUid == user.uid) return;
    _registeredUid = user.uid;

    try {
      final preferences = await ref
          .read(notificationRepositoryProvider)
          .watchPreferences(user.uid)
          .first;
      if (!mounted || !preferences.enabled) return;
      await ref.read(notificationServiceProvider).enableForUser(user.uid);
    } catch (_) {
      // FCM hiçbir zaman login/app bootstrap akışını bloke etmemeli.
    }
  }

  String? _safeRouteFromData(Map<String, dynamic> data) {
    final route = data['route']?.toString();

    const allowedRoutes = <String>{
      AppRoutes.home,
      AppRoutes.content,
      AppRoutes.dersProgrami,
      AppRoutes.hedefler,
      AppRoutes.sorular,
      AppRoutes.ayarlar,
      AppRoutes.aiSolver,
      AppRoutes.billing,
      AppRoutes.analytics,
    };

    return allowedRoutes.contains(route) ? route : null;
  }

  void _openData(Map<String, dynamic> data) {
    final route = _safeRouteFromData(data);
    if (route == null || !mounted) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(
      authStateProvider,
      (previous, next) => next.whenData(_syncCurrentUser),
    );
    return widget.child;
  }

  @override
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    super.dispose();
  }
}

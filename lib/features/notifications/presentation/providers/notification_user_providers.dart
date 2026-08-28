import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/notification_preferences.dart';
import 'notification_providers.dart';

final notificationPreferencesProvider =
    StreamProvider.autoDispose<NotificationPreferences>((ref) {
      final user = ref.watch(currentFirebaseUserProvider);
      if (user == null) {
        return Stream.value(const NotificationPreferences());
      }
      return ref
          .watch(notificationRepositoryProvider)
          .watchPreferences(user.uid);
    });

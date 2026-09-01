import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../core/errors/auth_error_mapper.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/billing/presentation/providers/billing_providers.dart';
import '../features/notifications/domain/notification_preferences.dart';
import '../features/notifications/presentation/providers/notification_providers.dart';
import '../features/notifications/presentation/providers/notification_user_providers.dart';

class Ayarlar extends ConsumerStatefulWidget {
  const Ayarlar({super.key});

  @override
  ConsumerState<Ayarlar> createState() => _AyarlarState();
}

class _AyarlarState extends ConsumerState<Ayarlar> {
  bool _accountActionInProgress = false;

  Future<void> logout() async {
    if (_accountActionInProgress) return;
    setState(() => _accountActionInProgress = true);

    final success = await ref.read(authControllerProvider.notifier).signOut();

    if (!mounted) return;
    setState(() => _accountActionInProgress = false);

    if (success) {
      context.go(AppRoutes.login);
      return;
    }

    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      _showMessage(AuthErrorMapper.message(state.error!));
    }
  }

  Future<void> deleteAccount() async {
    if (_accountActionInProgress) return;

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı sil'),
        content: const Text(
          'Hesabını silmek istediğine emin misin? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );

    if (approved != true || !mounted) return;

    setState(() => _accountActionInProgress = true);
    final success = await ref
        .read(authControllerProvider.notifier)
        .deleteCurrentAccount();

    if (!mounted) return;
    setState(() => _accountActionInProgress = false);

    if (success) {
      _showMessage('Hesabınız başarıyla silindi.');
      context.go(AppRoutes.login);
      return;
    }

    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      _showMessage(AuthErrorMapper.message(state.error!));
    }
  }

  Future<void> _setNotificationsEnabled(
    NotificationPreferences current,
    bool enabled,
  ) async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;

    final next = current.copyWith(enabled: enabled);
    try {
      await ref
          .read(notificationRepositoryProvider)
          .savePreferences(user.uid, next);

      if (enabled) {
        final allowed = await ref
            .read(notificationServiceProvider)
            .enableForUser(user.uid);
        if (!allowed && mounted) {
          _showMessage(
            'Bildirim izni verilmedi. Telefon ayarlarından Çalış 360 bildirimlerini açabilirsin.',
          );
        }
      } else {
        await ref.read(notificationServiceProvider).disableForUser(user.uid);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Bildirim ayarı kaydedilemedi: $error');
      }
    }
  }

  Future<void> _saveNotificationPreference(
    NotificationPreferences current,
    NotificationPreferences next,
  ) async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;

    try {
      await ref
          .read(notificationRepositoryProvider)
          .savePreferences(user.uid, next);
    } catch (error) {
      if (mounted) {
        _showMessage('Bildirim tercihi kaydedilemedi: $error');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider);
    final billingState = ref.watch(billingControllerProvider);
    final notificationPreferences = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const _SettingsHero(),
            const SizedBox(height: 20),
            _SectionLabel('Hesabım'),
            const SizedBox(height: 8),
            appUser.when(
              data: (user) => Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFD6C5BB), width: 1.7),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person_outline_rounded),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName?.trim().isNotEmpty == true
                                  ? user!.displayName!
                                  : 'Çalış 360 Öğrencisi',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? '',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetaPill(
                                  'Plan ${(user?.plan ?? 'free').toUpperCase()}',
                                ),
                                _MetaPill('${user?.creditBalance ?? 0} kredi'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: LinearProgressIndicator(),
                ),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text('Profil bilgileri şu anda yüklenemedi: $error'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFD6C5BB), width: 1.7),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: const _SettingsIcon(Icons.workspace_premium_outlined),
                title: const Text(
                  'Premium & AI Kredileri',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  billingState.status?.subscription.active == true
                      ? 'Premium aktif • ${billingState.status?.creditBalance ?? 0} AI kredisi'
                      : '${billingState.status?.creditBalance ?? 0} AI kredisi • Planları ve mağaza fiyatlarını görüntüle',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoutes.billing),
              ),
            ),
            const SizedBox(height: 22),
            _SectionLabel('Bildirimler'),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFD6C5BB), width: 1.7),
              ),
              child: notificationPreferences.when(
                data: (preferences) => Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      value: preferences.enabled,
                      onChanged: (value) =>
                          _setNotificationsEnabled(preferences, value),
                      secondary: const _SettingsIcon(
                        Icons.notifications_none_rounded,
                      ),
                      title: const Text(
                        'Bildirimleri kullan',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Çalışma, sınav ve hedef hatırlatmalarını yönet.',
                      ),
                    ),
                    if (preferences.enabled) ...[
                      const Divider(height: 1),
                      _PreferenceSwitch(
                        title: 'Ders çalışma hatırlatmaları',
                        value: preferences.studyReminders,
                        onChanged: (value) => _saveNotificationPreference(
                          preferences,
                          preferences.copyWith(studyReminders: value),
                        ),
                      ),
                      _PreferenceSwitch(
                        title: 'Sınav hatırlatmaları',
                        value: preferences.examReminders,
                        onChanged: (value) => _saveNotificationPreference(
                          preferences,
                          preferences.copyWith(examReminders: value),
                        ),
                      ),
                      _PreferenceSwitch(
                        title: 'Hedef hatırlatmaları',
                        value: preferences.goalReminders,
                        onChanged: (value) => _saveNotificationPreference(
                          preferences,
                          preferences.copyWith(goalReminders: value),
                        ),
                      ),
                      _PreferenceSwitch(
                        title: 'Haftalık çalışma raporu',
                        value: preferences.weeklyReports,
                        onChanged: (value) => _saveNotificationPreference(
                          preferences,
                          preferences.copyWith(weeklyReports: value),
                        ),
                      ),
                    ],
                  ],
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(18),
                  child: LinearProgressIndicator(),
                ),
                error: (error, _) => ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const _SettingsIcon(
                    Icons.notifications_off_outlined,
                  ),
                  title: const Text('Bildirim ayarları yüklenemedi'),
                  subtitle: Text(error.toString()),
                ),
              ),
            ),
            const SizedBox(height: 22),
            _SectionLabel('Oturum'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _accountActionInProgress ? null : logout,
                icon: _accountActionInProgress
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                label: const Text('Çıkış Yap'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _accountActionInProgress ? null : deleteAccount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.25),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Hesabımı Sil'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SettingsHero extends StatelessWidget {
  const _SettingsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A1F2C), Color(0xFF1F4A3D)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x241685C8), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: const Row(
        children: [
          _SettingsHeroIcon(),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Uygulaman senin kontrolünde',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('Hesabını, bildirimlerini ve premium seçeneklerini buradan yönet.',
                  style: TextStyle(color: Color(0xE6FFFFFF), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHeroIcon extends StatelessWidget {
  const _SettingsHeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 28),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon);
  static const Color color = Color(0xFF4A1F2C);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: 21, color: color),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 68, right: 16),
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}

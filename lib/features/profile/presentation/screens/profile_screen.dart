import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../billing/presentation/providers/billing_providers.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider);
    final billing = ref.watch(billingControllerProvider);
    final gamification = ref.watch(gamificationSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.ayarlar),
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(gamificationSummaryProvider);
          ref.invalidate(currentAppUserProvider);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            user.when(
              loading: () => const _LoadingCard(),
              error: (error, _) => _MessageCard(
                icon: Icons.error_outline_rounded,
                message: 'Profil bilgileri yüklenemedi: $error',
              ),
              data: (value) {
                final displayName = value?.displayName?.trim();
                return _ProfileHero(
                  name: displayName?.isNotEmpty == true
                      ? displayName!
                      : 'Çalış 360 Öğrencisi',
                  email: value?.email ?? '',
                  premium: value?.isPremium == true,
                  credits:
                      billing.status?.creditBalance ?? value?.creditBalance ?? 0,
                );
              },
            ),
            const SizedBox(height: 14),
            gamification.when(
              loading: () => const _LoadingCard(),
              error: (_, _) => const _MessageCard(
                icon: Icons.insights_outlined,
                message: 'İstatistikler şu anda yüklenemedi. Yenilemek için aşağı çekebilirsin.',
              ),
              data: (value) => _StatsGrid(
                streak: value.currentStreak,
                score: value.score,
                solved: value.solvedCount,
                accuracy: value.accuracyPercent,
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle(
              title: 'Hızlı erişim',
              subtitle: 'En çok kullandığın alanlara tek dokunuşla geç.',
            ),
            const SizedBox(height: 10),
            _QuickActions(
              onProgram: () => context.push(AppRoutes.dersProgrami),
              onQuestions: () => context.push(AppRoutes.sorular),
              onAnalytics: () => context.go(AppRoutes.analytics),
            ),
            const SizedBox(height: 24),
            const _SectionTitle(
              title: 'Hesap & uygulama',
              subtitle: 'Üyelik, hedef ve uygulama tercihlerini yönet.',
            ),
            const SizedBox(height: 10),
            _ProfileMenuCard(
              items: [
                _ProfileMenuItem(
                  icon: Icons.workspace_premium_outlined,
                  iconColor: const Color(0xFF6C55E0),
                  iconBackground: const Color(0xFFF0ECFF),
                  title: 'Premium & AI Kredileri',
                  subtitle: 'Planını ve kredi bakiyeni yönet',
                  onTap: () => context.push(AppRoutes.billing),
                ),
                _ProfileMenuItem(
                  icon: Icons.flag_outlined,
                  iconColor: const Color(0xFFE6653C),
                  iconBackground: const Color(0xFFFFF0EA),
                  title: 'Hedeflerim',
                  subtitle: 'Hedeflerini görüntüle ve düzenle',
                  onTap: () => context.push(AppRoutes.hedefler),
                ),
                _ProfileMenuItem(
                  icon: Icons.settings_outlined,
                  iconColor: const Color(0xFF1685C8),
                  iconBackground: const Color(0xFFEAF6FF),
                  title: 'Ayarlar',
                  subtitle: 'Bildirimler, hesap ve uygulama tercihleri',
                  onTap: () => context.push(AppRoutes.ayarlar),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.email,
    required this.premium,
    required this.credits,
  });

  final String name;
  final String email;
  final bool premium;
  final int credits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(
        borderColor: const Color(0xFFBFD6E6),
        shadowColor: const Color(0xFF1685C8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF20A8E8), Color(0xFF6C55E0)],
                  ),
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1685C8).withValues(alpha: 0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _Pill(
                          icon: premium
                              ? Icons.workspace_premium_rounded
                              : Icons.school_outlined,
                          text: premium ? 'Premium' : 'Ücretsiz',
                          color: premium
                              ? const Color(0xFF6C55E0)
                              : const Color(0xFF1677B8),
                          background: premium
                              ? const Color(0xFFF0ECFF)
                              : const Color(0xFFEAF6FF),
                        ),
                        _Pill(
                          icon: Icons.bolt_rounded,
                          text: '$credits kredi',
                          color: const Color(0xFF17895C),
                          background: const Color(0xFFE9F8F1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F9FD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFD7E7F2),
                width: 1.25,
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF1685C8),
                  size: 20,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Serini koru, günlük planını tamamla ve puanını yükselt.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.streak,
    required this.score,
    required this.solved,
    required this.accuracy,
  });

  final int streak;
  final int score;
  final int solved;
  final int? accuracy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final items = [
          _MetricCard(
            icon: Icons.local_fire_department_rounded,
            label: 'Seri',
            value: '$streak gün',
            color: const Color(0xFFE6653C),
            background: const Color(0xFFFFF0EA),
          ),
          _MetricCard(
            icon: Icons.workspace_premium_outlined,
            label: 'Puan',
            value: '$score',
            color: const Color(0xFF6C55E0),
            background: const Color(0xFFF0ECFF),
          ),
          _MetricCard(
            icon: Icons.task_alt_rounded,
            label: 'Çözüm',
            value: '$solved',
            color: const Color(0xFF17895C),
            background: const Color(0xFFE9F8F1),
          ),
          _MetricCard(
            icon: Icons.insights_rounded,
            label: 'Doğruluk',
            value: accuracy == null ? '--' : '%$accuracy',
            color: const Color(0xFF1685C8),
            background: const Color(0xFFEAF6FF),
          ),
        ];

        if (compact) {
          return GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: items,
          );
        }

        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: items[i]),
              if (i != items.length - 1) const SizedBox(width: 9),
            ],
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.24), width: 1.55),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onProgram,
    required this.onQuestions,
    required this.onAnalytics,
  });

  final VoidCallback onProgram;
  final VoidCallback onQuestions;
  final VoidCallback onAnalytics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.calendar_month_rounded,
            title: 'Program',
            color: const Color(0xFF6C55E0),
            background: const Color(0xFFF0ECFF),
            onTap: onProgram,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.folder_copy_outlined,
            title: 'Kayıtlar',
            color: const Color(0xFF17895C),
            background: const Color(0xFFE9F8F1),
            onTap: onQuestions,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.insights_rounded,
            title: 'Analiz',
            color: const Color(0xFF1685C8),
            background: const Color(0xFFEAF6FF),
            onTap: onAnalytics,
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.22),
              width: 1.55,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.07),
                blurRadius: 11,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard({required this.items});

  final List<_ProfileMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 7,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: items[i].iconBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: items[i].iconColor.withValues(alpha: 0.14),
                  ),
                ),
                child: Icon(items[i].icon, color: items[i].iconColor),
              ),
              title: Text(
                items[i].title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(items[i].subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: items[i].onTap,
            ),
            if (i != items.length - 1)
              const Divider(height: 1, indent: 74, endIndent: 12),
          ],
        ],
      ),
    );
  }
}

class _ProfileMenuItem {
  const _ProfileMenuItem({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: const LinearProgressIndicator(),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration({Color? borderColor, Color? shadowColor}) {
  final shadow = shadowColor ?? const Color(0xFF172033);
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: borderColor ?? const Color(0xFFD5E0E8),
      width: 1.6,
    ),
    boxShadow: [
      BoxShadow(
        color: shadow.withValues(alpha: 0.07),
        blurRadius: 15,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

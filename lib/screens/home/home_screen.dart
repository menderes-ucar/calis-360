import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zirve/screens/home/home_hedef_ekle.dart';

import '../../app/router.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/gamification/domain/gamification_summary.dart';
import '../../features/gamification/presentation/providers/gamification_providers.dart';
import '../../features/study_planner/presentation/screens/ai_study_planner_screen.dart';
import '../../features/study_data/presentation/providers/study_data_providers.dart';
import '../../models/home_hedef_ekle.dart';
import '../../widgets/home_widget/home_card_style.dart';
import '../../widgets/home_widget/home_widget.dart';
import '../../widgets/home_widget/home_widget_sayim.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = ref.read(homeHedefRepositoryProvider);
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final gamification = ref.watch(gamificationSummaryProvider);
    final displayName = appUser?.displayName?.trim();
    final greetingName = displayName?.isNotEmpty == true ? displayName! : 'Öğrenci';

    return Scaffold(
      backgroundColor: HomeCardStyle.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: HomeCardStyle.forest,
          onRefresh: () async {
            ref.invalidate(gamificationSummaryProvider);
            await Future<void>.delayed(const Duration(milliseconds: 250));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 112),
            children: [
              _TopBar(
                greetingName: greetingName,
                onProfile: () => context.go('/profile'),
              ),
              const SizedBox(height: 24),
              _HeroPlannerCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiStudyPlannerScreen()),
                ),
              ),
              const SizedBox(height: 16),
              gamification.when(
                loading: () => const _MetricsLoading(),
                error: (_, _) => _MetricsError(
                  onRetry: () => ref.invalidate(gamificationSummaryProvider),
                ),
                data: (summary) => _MetricStrip(summary: summary),
              ),
              const SizedBox(height: 28),
              const _SectionHeader(
                eyebrow: 'BUGÜN',
                title: 'Çalışma ritmin',
              ),
              const SizedBox(height: 12),
              StreamBuilder<HomeHedef?>(
                stream: repo.getHomeHedefForCurrentUser(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _SoftLoadingCard();
                  }
                  final hedef = snapshot.data;
                  return _GoalCard(
                    onTap: _openGoalEditor,
                    title: hedef == null ? 'Hedefini oluştur' : '${hedef.uni} • ${hedef.bolum}',
                    subtitle: hedef == null
                        ? 'Rotanı belirle, çalışma planını hedefinle aynı çizgiye getir.'
                        : 'Hedefin hazır. Günlük çalışmalarını bu rotada ilerlet.',
                    value: hedef == null ? 'HEDEF EKLE' : '${hedef.net} NET',
                  );
                },
              ),
              const SizedBox(height: 12),
              const CountdownWidget(),
              const SizedBox(height: 28),
              const _SectionHeader(
                eyebrow: 'KISA YOLLAR',
                title: 'Odak alanın',
              ),
              const SizedBox(height: 12),
              _EditorialActionCard(
                icon: Icons.bolt_rounded,
                title: 'AI ile soru çöz',
                subtitle: 'Takıldığın soruyu yükle, çözümü adım adım incele.',
                tone: HomeCardStyle.burgundy,
                onTap: () => context.go(AppRoutes.aiSolver),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CompactActionCard(
                      icon: Icons.auto_stories_rounded,
                      title: 'Konu Özetleri',
                      subtitle: 'Hızlı tekrar',
                      onTap: () => context.push(AppRoutes.content),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CompactActionCard(
                      icon: Icons.insights_rounded,
                      title: 'Analizler',
                      subtitle: 'İlerlemeni gör',
                      onTap: () => context.go(AppRoutes.analytics),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _SectionHeader(
                eyebrow: 'MERKEZ',
                title: 'Çalışmanı yönet',
              ),
              const SizedBox(height: 12),
              _ManagementPanel(
                items: [
                  _ManagementItem(
                    icon: Icons.calendar_month_rounded,
                    title: 'Program',
                    subtitle: 'Haftalık plan ve takvim',
                    onTap: () => context.push(AppRoutes.dersProgrami),
                  ),
                  _ManagementItem(
                    icon: Icons.folder_copy_rounded,
                    title: 'Sınav & Sorular',
                    subtitle: 'Kayıtlarını düzenle',
                    onTap: () => context.push(AppRoutes.sorular),
                  ),
                  _ManagementItem(
                    icon: Icons.flag_rounded,
                    title: 'Hedefler',
                    subtitle: 'Rotanı güncel tut',
                    onTap: () => context.push(AppRoutes.hedefler),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SectionHeader(
                eyebrow: 'KÜTÜPHANE',
                title: 'Derslere göz at',
                trailing: TextButton(
                  onPressed: () => context.push(AppRoutes.content),
                  style: TextButton.styleFrom(foregroundColor: HomeCardStyle.forest),
                  child: const Text('Tümünü gör'),
                ),
              ),
              const SizedBox(height: 12),
              const BannerWidgetArea(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openGoalEditor() async {
    final repo = ref.read(homeHedefRepositoryProvider);
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => HomeHedefEkle()),
    );
    if (result != null && result is Map<String, String>) {
      await repo.addOrUpdateHedefForCurrentUser(
        net: int.tryParse(result['hedefNet'] ?? '0') ?? 0,
        uni: result['universite'] ?? '',
        bolum: result['bolum'] ?? '',
      );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.greetingName, required this.onProfile});
  final String greetingName;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ÇALIŞ 360',
                style: TextStyle(
                  color: HomeCardStyle.forest,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Merhaba, $greetingName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HomeCardStyle.ink,
                  fontSize: 27,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: HomeCardStyle.surface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onProfile,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: HomeCardStyle.borderColor),
              ),
              child: const Icon(Icons.person_outline_rounded, color: HomeCardStyle.burgundy),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPlannerCard extends StatelessWidget {
  const _HeroPlannerCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: HomeCardStyle.forest,
            borderRadius: BorderRadius.circular(28),
            boxShadow: HomeCardStyle.shadows(accent: HomeCardStyle.forest),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: HomeCardStyle.background,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'AI PLANLAYICI',
                      style: TextStyle(
                        color: HomeCardStyle.forest,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '10 KREDİ',
                    style: TextStyle(
                      color: HomeCardStyle.background.withValues(alpha: .72),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text(
                'Haftanı\nzekice planla.',
                style: TextStyle(
                  color: HomeCardStyle.background,
                  fontSize: 31,
                  height: .98,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Derslerini, hedefini ve zamanını seç. Sana uygun çalışma akışını AI oluştursun.',
                style: TextStyle(
                  color: HomeCardStyle.background.withValues(alpha: .78),
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Text(
                    'Program oluştur',
                    style: TextStyle(
                      color: HomeCardStyle.background,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: HomeCardStyle.burgundy,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: HomeCardStyle.background, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.eyebrow, required this.title, this.trailing});
  final String eyebrow;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: HomeCardStyle.burgundy,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: HomeCardStyle.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.45,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.summary});
  final GamificationSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 17),
      decoration: BoxDecoration(
        color: HomeCardStyle.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeCardStyle.borderColor),
      ),
      child: Row(
        children: [
          _Metric(value: '${summary.currentStreak}', label: 'GÜN SERİ'),
          const _MetricDivider(),
          _Metric(value: '${summary.solvedCount}', label: 'SORU'),
          const _MetricDivider(),
          _Metric(value: '${summary.score}', label: 'PUAN'),
          const _MetricDivider(),
          _Metric(
            value: summary.accuracyPercent == null ? '—' : '%${summary.accuracyPercent}',
            label: 'DOĞRULUK',
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: HomeCardStyle.burgundy, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: HomeCardStyle.muted, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: .4),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 34, color: HomeCardStyle.borderColor);
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.onTap, required this.title, required this.subtitle, required this.value});
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeCardStyle.surface,
      borderRadius: BorderRadius.circular(HomeCardStyle.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeCardStyle.radius),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HomeCardStyle.radius),
            border: Border.all(color: HomeCardStyle.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(color: HomeCardStyle.burgundy, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.flag_rounded, color: HomeCardStyle.background, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: HomeCardStyle.ink, fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: HomeCardStyle.muted, fontSize: 11.5, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(value, style: const TextStyle(color: HomeCardStyle.forest, fontWeight: FontWeight.w900, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorialActionCard extends StatelessWidget {
  const _EditorialActionCard({required this.icon, required this.title, required this.subtitle, required this.tone, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tone,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: HomeCardStyle.background.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: HomeCardStyle.background),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: HomeCardStyle.background, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: HomeCardStyle.background.withValues(alpha: .72), fontSize: 11.5, height: 1.35)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: HomeCardStyle.background),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactActionCard extends StatelessWidget {
  const _CompactActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeCardStyle.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: HomeCardStyle.borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: HomeCardStyle.forest, size: 25),
              const SizedBox(height: 20),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: HomeCardStyle.ink, fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: HomeCardStyle.muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagementPanel extends StatelessWidget {
  const _ManagementPanel({required this.items});
  final List<_ManagementItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HomeCardStyle.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomeCardStyle.borderColor),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _ManagementRow(item: items[i]),
            if (i != items.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 66),
                child: Divider(height: 1, color: HomeCardStyle.borderColor),
              ),
          ],
        ],
      ),
    );
  }
}

class _ManagementRow extends StatelessWidget {
  const _ManagementRow({required this.item});
  final _ManagementItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: HomeCardStyle.background, borderRadius: BorderRadius.circular(12)),
              child: Icon(item.icon, color: HomeCardStyle.burgundy, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(color: HomeCardStyle.ink, fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: const TextStyle(color: HomeCardStyle.muted, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: HomeCardStyle.forest),
          ],
        ),
      ),
    );
  }
}

class _ManagementItem {
  const _ManagementItem({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _MetricsLoading extends StatelessWidget {
  const _MetricsLoading();
  @override
  Widget build(BuildContext context) => const _SoftLoadingCard();
}

class _SoftLoadingCard extends StatelessWidget {
  const _SoftLoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HomeCardStyle.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeCardStyle.borderColor),
      ),
      child: const Center(child: LinearProgressIndicator(color: HomeCardStyle.forest, backgroundColor: HomeCardStyle.background)),
    );
  }
}

class _MetricsError extends StatelessWidget {
  const _MetricsError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: HomeCardStyle.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeCardStyle.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.refresh_rounded, color: HomeCardStyle.burgundy),
          const SizedBox(width: 10),
          const Expanded(child: Text('İstatistikler şu anda yüklenemedi.', style: TextStyle(color: HomeCardStyle.ink, fontWeight: FontWeight.w800))),
          TextButton(onPressed: onRetry, style: TextButton.styleFrom(foregroundColor: HomeCardStyle.forest), child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

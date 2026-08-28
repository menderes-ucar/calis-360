import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zirve/screens/home/home_hedef_ekle.dart';

import '../../app/router.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/gamification/domain/gamification_summary.dart';
import '../../features/gamification/presentation/providers/gamification_providers.dart';
import '../../features/study_data/presentation/providers/study_data_providers.dart';
import '../../models/home_hedef_ekle.dart';
import '../../widgets/home_widget/home_widget.dart';
import '../../widgets/home_widget/home_widget_sayim.dart';
import '../../widgets/home_widget/home_card_style.dart';

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
    final greetingName = displayName?.isNotEmpty == true
        ? displayName!
        : 'Öğrenci';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çalış 360'),
        actions: [
          IconButton(
            onPressed: () => context.go('/profile'),
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(gamificationSummaryProvider);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            Text(
              'Merhaba, $greetingName 👋',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bugünkü planına hızlıca devam et.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            const SizedBox(height: 18),
            _SectionHeader(
              title: 'Hedefin',
              trailing: TextButton(
                onPressed: _openGoalEditor,
                child: const Text('Düzenle'),
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<HomeHedef?>(
              stream: repo.getHomeHedefForCurrentUser(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Card(
                    elevation: 4,
                    shadowColor: const Color(0xFF172033).withValues(alpha: 0.16),
                    shape: HomeCardStyle.shape,
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: LinearProgressIndicator(),
                    ),
                  );
                }

                final hedef = snapshot.data;
                if (hedef == null) {
                  return _GoalCard(
                    onTap: _openGoalEditor,
                    title: 'Hedefini oluştur',
                    subtitle:
                        'Hedef netini, üniversiteni ve bölümünü ekleyerek planını kişiselleştir.',
                    value: '--',
                  );
                }

                return _GoalCard(
                  onTap: _openGoalEditor,
                  title: '${hedef.uni} • ${hedef.bolum}',
                  subtitle: 'Hedefine göre ilerlemeni düzenli takip et.',
                  value: '${hedef.net} net',
                );
              },
            ),
            const SizedBox(height: 14),
            const CountdownWidget(),
            const SizedBox(height: 22),
            _SectionHeader(title: 'Hızlı Başla'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.bolt_rounded,
                    title: 'Soru Çöz',
                    subtitle: 'AI ile adım adım çözüm',
                    colors: const [Color(0xFF1FA8E8), Color(0xFF6E62E8)],
                    onTap: () => context.go(AppRoutes.aiSolver),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.insights_rounded,
                    title: 'Analizler',
                    subtitle: 'Gelişimini detaylı gör',
                    colors: const [Color(0xFF7156D9), Color(0xFF4A7ED8)],
                    onTap: () => context.go(AppRoutes.analytics),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionHeader(title: 'Çalışma Alanların'),
            const SizedBox(height: 10),
            _ModuleGrid(
              items: [
                _ModuleItem(
                  icon: Icons.auto_stories_outlined,
                  title: 'Dersler',
                  subtitle: 'Konu özetleri ve üniteler',
                  color: const Color(0xFF1685C8),
                  background: const Color(0xFFEAF6FF),
                  onTap: () => context.push(AppRoutes.content),
                ),
                _ModuleItem(
                  icon: Icons.calendar_month_outlined,
                  title: 'Program',
                  subtitle: 'Çalışma planın ve takvim',
                  color: const Color(0xFF6C55E0),
                  background: const Color(0xFFF0ECFF),
                  onTap: () => context.push(AppRoutes.dersProgrami),
                ),
                _ModuleItem(
                  icon: Icons.folder_copy_outlined,
                  title: 'Sınav & Sorular',
                  subtitle: 'Kayıtlarını yönet',
                  color: const Color(0xFF17895C),
                  background: const Color(0xFFE9F8F1),
                  onTap: () => context.push(AppRoutes.sorular),
                ),
                _ModuleItem(
                  icon: Icons.flag_outlined,
                  title: 'Hedefler',
                  subtitle: 'Planını ve hedefini takip et',
                  color: const Color(0xFFE6653C),
                  background: const Color(0xFFFFF0EA),
                  onTap: () => context.push(AppRoutes.hedefler),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'Derslere Göz At',
              trailing: TextButton(
                onPressed: () => context.push(AppRoutes.content),
                child: const Text('Tüm dersler'),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Bir derse dokunarak konu özetlerine ve ünitelerine geçebilirsin.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            const BannerWidgetArea(),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoalEditor() async {
    final repo = ref.read(homeHedefRepositoryProvider);
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => HomeHedefEkle()));

    if (result != null && result is Map<String, String>) {
      await repo.addOrUpdateHedefForCurrentUser(
        net: int.tryParse(result['hedefNet'] ?? '0') ?? 0,
        uni: result['universite'] ?? '',
        bolum: result['bolum'] ?? '',
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final cards = [
          _MetricCard(
            icon: Icons.local_fire_department_rounded,
            label: 'Çalışma Serisi',
            value: '${summary.currentStreak}',
            suffix: 'gün',
            color: const Color(0xFFE6653C),
            background: const Color(0xFFFFF0EA),
          ),
          _MetricCard(
            icon: Icons.bolt_rounded,
            label: 'Çözülen',
            value: '${summary.solvedCount}',
            suffix: 'soru',
            color: const Color(0xFF1685C8),
            background: const Color(0xFFEAF6FF),
          ),
          _MetricCard(
            icon: Icons.workspace_premium_outlined,
            label: 'Başarı Puanı',
            value: '${summary.score}',
            suffix: 'puan',
            color: const Color(0xFF6C55E0),
            background: const Color(0xFFF0ECFF),
          ),
          _MetricCard(
            icon: Icons.task_alt_rounded,
            label: 'Doğruluk',
            value: summary.accuracyPercent == null
                ? '--'
                : '%${summary.accuracyPercent}',
            suffix: summary.accuracyPercent == null ? 'veri yok' : 'başarı',
            color: const Color(0xFF17895C),
            background: const Color(0xFFE9F8F1),
          ),
        ];

        if (compact) {
          return GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: cards,
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 10),
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
    required this.suffix,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final String value;
  final String suffix;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
          width: HomeCardStyle.borderWidth,
        ),
        boxShadow: HomeCardStyle.shadows(accent: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            suffix,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsLoading extends StatelessWidget {
  const _MetricsLoading();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: const Color(0xFF172033).withValues(alpha: 0.16),
      shape: HomeCardStyle.shape,
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class _MetricsError extends StatelessWidget {
  const _MetricsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 4,
      shadowColor: const Color(0xFF172033).withValues(alpha: 0.12),
      shape: HomeCardStyle.shape,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: colors.onErrorContainer,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'İstatistikler şu anda yüklenemedi.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: const Color(0xFF172033).withValues(alpha: 0.16),
      shape: HomeCardStyle.shape,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Color(0xFF1685C8),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF1685C8),
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: HomeCardStyle.borderWidth,
            ),
            boxShadow: HomeCardStyle.shadows(accent: colors.first),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 27),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({required this.items});

  final List<_ModuleItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          elevation: 4,
          shadowColor: const Color(0xFF172033).withValues(alpha: 0.16),
          shape: HomeCardStyle.shape,
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.background,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(item.icon, color: item.color, size: 21),
                  ),
                  const Spacer(),
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModuleItem {
  const _ModuleItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;
}

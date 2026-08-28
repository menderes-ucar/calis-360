import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../billing/presentation/providers/billing_providers.dart';
import '../../domain/analytics_models.dart';
import '../providers/student_analytics_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingControllerProvider);
    final premium = billing.status?.subscription.active == true;

    if (billing.status == null && !billing.loading) {
      Future.microtask(
        () => ref.read(billingControllerProvider.notifier).initialize(),
      );
    }

    if (billing.loading && billing.status == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analiz Merkezi')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!premium) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analiz Merkezi')),
        body: _PremiumAnalyticsGate(
          onPremium: () => context.push(AppRoutes.billing),
        ),
      );
    }

    final analytics = ref.watch(studentAnalyticsReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiz Merkezi'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(studentAnalyticsReportProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: analytics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: 'Analiz verileri hazırlanamadı: $error',
          onRetry: () => ref.invalidate(studentAnalyticsReportProvider),
        ),
        data: (report) => _AnalyticsBody(report: report),
      ),
    );
  }
}

class _PremiumAnalyticsGate extends StatelessWidget {
  const _PremiumAnalyticsGate({required this.onPremium});

  final VoidCallback onPremium;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Gelişimini sadece netlerle değil, nedenleriyle gör.',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Premium Analiz Merkezi; sınavlarını, konu bazlı yanlışlarını, AI yardım geçmişini, çalışma programını ve hedeflerini tek raporda birleştirir.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 20),
              const _GateBenefit(
                icon: Icons.track_changes_rounded,
                title: 'Konu hakimiyet haritası',
                text:
                    'Hangi konunun güçlü, zayıf veya kritik olduğunu veri güveniyle birlikte gör.',
              ),
              const _GateBenefit(
                icon: Icons.trending_up_rounded,
                title: 'Sınav ve ders trendleri',
                text:
                    'Net değişimini, ders bazlı yükseliş ve düşüşleri karşılaştır.',
              ),
              const _GateBenefit(
                icon: Icons.error_outline_rounded,
                title: 'Yanlış ve AI yardım sinyalleri',
                text:
                    'Tekrarlanan yanlışları ve sık AI yardımı alınan konuları önceliklendir.',
              ),
              const _GateBenefit(
                icon: Icons.auto_awesome_rounded,
                title: 'Kişisel çalışma önerileri',
                text:
                    'Hedef, çalışma ve performans verilerine göre neye odaklanacağını gör.',
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPremium,
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('Premium ayrıcalıklarını gör'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GateBenefit extends StatelessWidget {
  const _GateBenefit({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    if (!report.hasUsefulData) {
      return const _EmptyAnalyticsView();
    }

    final topRecommendation = report.recommendations.isEmpty
        ? null
        : report.recommendations.first;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _AnalyticsHero(report: report),
        const SizedBox(height: 14),
        _OverviewCard(report: report),
        const SizedBox(height: 12),
        _PremiumSummaryStrip(report: report),
        if (topRecommendation != null) ...[
          const SizedBox(height: 12),
          _FocusCard(item: topRecommendation),
        ],
        const SizedBox(height: 22),
        Text(
          'Detaylar',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'İhtiyacın olan başlığı aç. Tüm veriler burada duruyor; ilk bakışta yalnızca önemli olanları gösteriyoruz.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        if (report.examTrend.isNotEmpty)
          _AnalyticsSection(
            icon: Icons.show_chart_rounded,
            title: 'Sınav gelişimi',
            subtitle: '${report.examCount} sınavdan gelen net trendi',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrendCard(points: report.examTrend),
                const SizedBox(height: 8),
                Text(
                  report.datedExamCount >= 2
                      ? 'Tarih bilgisi olan sınavlar kronolojik karşılaştırılır.'
                      : 'Daha güvenilir trend için tarihli en az 2 sınav ekle.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        if (report.subjects.isNotEmpty)
          _AnalyticsSection(
            icon: Icons.menu_book_outlined,
            title: 'Ders performansı',
            subtitle: 'Hangi ders yükseliyor, hangisi ilgi istiyor?',
            child: Column(
              children: [
                for (final item in report.subjects.take(8)) ...[
                  _SubjectCard(item),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        if (report.topics.isNotEmpty)
          _AnalyticsSection(
            icon: Icons.track_changes_rounded,
            title: 'Konu başarı haritası',
            subtitle: 'Konu bazında başarı, risk ve çalışma sinyalleri',
            child: Column(
              children: [
                for (final item in report.topics.take(8)) ...[
                  _TopicCard(item),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        _AnalyticsSection(
          icon: Icons.event_available_outlined,
          title: 'Çalışma & hedef düzeni',
          subtitle: 'Program ve hedef tamamlama görünümü',
          child: _StudyCard(study: report.study, goals: report.goals),
        ),
        if (report.recommendations.isNotEmpty)
          _AnalyticsSection(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Tüm öneriler',
            subtitle: '${report.recommendations.length} kişisel öneri',
            child: Column(
              children: [
                for (final item in report.recommendations) ...[
                  _RecommendationCard(item),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        if (report.insights.isNotEmpty)
          _AnalyticsSection(
            icon: Icons.insights_outlined,
            title: 'Dikkat çeken bulgular',
            subtitle: 'Gelişim, risk ve düzen sinyalleri',
            child: Column(
              children: [
                for (final item in report.insights) ...[
                  _InsightCard(item),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Analizler kayıtlı sınav, soru, AI çözümü, çalışma programı ve hedef verilerinden üretilir. Veri arttıkça güven seviyesi yükselir.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AnalyticsHero extends StatelessWidget {
  const _AnalyticsHero({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final delta = report.totalNetDelta;
    final improving = delta != null && delta > 0;
    final declining = delta != null && delta < 0;
    final accent = improving
        ? const Color(0xFF17895C)
        : declining
        ? const Color(0xFFE6653C)
        : const Color(0xFF1685C8);
    final soft = improving
        ? const Color(0xFFE9F8F1)
        : declining
        ? const Color(0xFFFFF0EA)
        : const Color(0xFFEAF6FF);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E0EA), width: 1.35),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.insights_rounded, color: accent, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performansını tek bakışta gör',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.examCount == 0
                      ? 'Sınav ve çalışma verilerin geldikçe analizlerin burada netleşecek.'
                      : '${report.examCount} sınav, ${report.aiSolveCount} AI çözümü ve çalışma kayıtların birlikte değerlendiriliyor.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
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

class _TrendAvatar extends StatelessWidget {
  const _TrendAvatar({required this.trend});

  final AnalyticsTrend trend;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (trend) {
      AnalyticsTrend.improving => (const Color(0xFF17895C), const Color(0xFFE9F8F1)),
      AnalyticsTrend.declining => (const Color(0xFFE6653C), const Color(0xFFFFF0EA)),
      AnalyticsTrend.stable => (const Color(0xFF1685C8), const Color(0xFFEAF6FF)),
      AnalyticsTrend.insufficient => (const Color(0xFF6C55E0), const Color(0xFFF0ECFF)),
    };
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(13)),
      child: Icon(_trendIcon(trend), color: color, size: 21),
    );
  }
}

class _PremiumSummaryStrip extends StatelessWidget {
  const _PremiumSummaryStrip({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final sortedTopics = [...report.topics]
      ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    final riskTopic = sortedTopics.isEmpty ? null : sortedTopics.first;

    final strongTopics = [...report.topics]
      ..sort((a, b) => b.masteryScore.compareTo(a.masteryScore));
    final strongTopic = strongTopics.isEmpty ? null : strongTopics.first;

    final declining = report.subjects
        .where((item) => item.trend == AnalyticsTrend.declining)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 18),
            const SizedBox(width: 7),
            Text(
              'Öne çıkanlar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 700
                ? (constraints.maxWidth - 20) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: width,
                  child: _PremiumMetricCard(
                    icon: Icons.priority_high_rounded,
                    accent: const Color(0xFFE6653C),
                    softAccent: const Color(0xFFFFF0EA),
                    label: 'Öncelikli konu',
                    value: riskTopic == null
                        ? 'Veri bekleniyor'
                        : '${riskTopic.subject} • ${riskTopic.topic}',
                    detail: riskTopic == null
                        ? 'Yanlış soru ve sınav verisi ekledikçe belirlenir.'
                        : 'Hakimiyet %${riskTopic.masteryScore} • Öncelik ${riskTopic.priorityScore}',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _PremiumMetricCard(
                    icon: Icons.verified_rounded,
                    accent: const Color(0xFF17895C),
                    softAccent: const Color(0xFFE9F8F1),
                    label: 'En güçlü konu',
                    value: strongTopic == null
                        ? 'Veri bekleniyor'
                        : '${strongTopic.subject} • ${strongTopic.topic}',
                    detail: strongTopic == null
                        ? 'Konu performansı oluştuğunda burada görünür.'
                        : 'Hakimiyet %${strongTopic.masteryScore} • Güven %${strongTopic.masteryConfidence}',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _PremiumMetricCard(
                    icon: Icons.monitor_heart_outlined,
                    accent: const Color(0xFF6C55E0),
                    softAccent: const Color(0xFFF0ECFF),
                    label: 'Risk sinyali',
                    value: declining == 0
                        ? 'Belirgin düşüş yok'
                        : '$declining derste düşüş',
                    detail:
                        '${report.topics.where((e) => e.recentDifficultQuestionCount > 0).length} konuda son 14 günde zorlanma kaydı var.',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PremiumMetricCard extends StatelessWidget {
  const _PremiumMetricCard({
    required this.icon,
    required this.accent,
    required this.softAccent,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final Color accent;
  final Color softAccent;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 1.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.item});

  final AnalyticsRecommendation item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1685C8), Color(0xFF6C55E0)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.center_focus_strong_rounded,
              color: theme.colorScheme.onPrimary,
              size: 28,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Şimdi buna odaklan',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary.withValues(
                        alpha: 0.72,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.action,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsSection extends StatelessWidget {
  const _AnalyticsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 21, color: const Color(0xFF1685C8)),
          ),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final delta = report.totalNetDelta;
    final deltaText = delta == null
        ? 'Karşılaştırma yok'
        : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} net';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1685C8).withValues(alpha: 0.24), width: 1.35),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Genel Durum',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.latestTotalNet == null
                            ? 'Henüz sınav neti yok'
                            : '${report.latestTotalNet!.toStringAsFixed(2)} net',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                _ConfidenceBadge(
                  label: report.confidenceLabel,
                  score: report.confidenceScore,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(_trendIcon(report.overallTrend), size: 18),
                  label: Text(deltaText),
                ),
                Chip(
                  avatar: const Icon(Icons.quiz_outlined, size: 18),
                  label: Text('${report.examCount} sınav'),
                ),
                Chip(
                  avatar: const Icon(Icons.insights_outlined, size: 18),
                  label: Text('${report.recommendations.length} öneri'),
                ),
                Chip(
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text('${report.aiSolveCount} AI çözümü'),
                ),
              ],
            ),
            if (report.confidenceScore < 45) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Analiz güveni şu an düşük. Daha fazla sınav, zorlandığın soru ve çalışma kaydı ekledikçe öneriler kişiselleşir.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('Analiz güveni', style: Theme.of(context).textTheme.labelMedium),
        Text(
          '$label • %$score',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points});

  final List<AnalyticsTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
        child: Column(
          children: [
            SizedBox(
              height: 170,
              width: double.infinity,
              child: CustomPaint(
                painter: _TrendPainter(
                  points: points,
                  lineColor: Theme.of(context).colorScheme.primary,
                  gridColor: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  points.first.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  points.last.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
  });

  final List<AnalyticsTrendPoint> points;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty) return;
    final values = points.map((point) => point.value).toList();
    var minValue = values.reduce((a, b) => math.min(a, b).toDouble());
    var maxValue = values.reduce((a, b) => math.max(a, b).toDouble());
    if ((maxValue - minValue).abs() < 0.01) {
      minValue -= 1;
      maxValue += 1;
    }

    final path = Path();
    final dotPaint = Paint()..color = lineColor;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : size.width * i / (points.length - 1);
      final normalized = (points[i].value - minValue) / (maxValue - minValue);
      final y = size.height - normalized * size.height;
      final offset = Offset(x, y.clamp(4.0, size.height - 4).toDouble());
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawCircle(offset, 4, dotPaint);
    }
    if (points.length > 1) canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard(this.item);

  final SubjectAnalytics item;

  @override
  Widget build(BuildContext context) {
    final trendText = switch (item.trend) {
      AnalyticsTrend.improving => 'Gelişiyor',
      AnalyticsTrend.declining => 'Düşüyor',
      AnalyticsTrend.stable => 'Dengeli',
      AnalyticsTrend.insufficient => 'Veri az',
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _TrendAvatar(trend: item.trend),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.subject,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.examCount == 0
                        ? 'Sınav verisi yok'
                        : 'Son net ${item.latestNet.toStringAsFixed(2)} • $trendText',
                  ),
                  Text(
                    '${item.difficultQuestionCount} zor soru'
                    '${item.studyCompletionRate == null ? '' : ' • Plan %${(item.studyCompletionRate! * 100).round()}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (item.examCount >= 2)
              Text(
                '${item.deltaNet >= 0 ? '+' : ''}${item.deltaNet.toStringAsFixed(1)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard(this.item);

  final TopicAnalytics item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = item.studyCompletionRate;
    final masteryColor = item.masteryScore >= 70
        ? theme.colorScheme.primary
        : item.masteryScore >= 50
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.subject} • ${item.topic}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Konu başarı skoru • ${item.masteryLabel}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '%${item.masteryScore}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: masteryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (item.masteryScore / 100).clamp(0.0, 1.0),
              minHeight: 8,
              color: masteryColor,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (item.wrongQuestionCount > 0)
                  Chip(label: Text('${item.wrongQuestionCount} yanlış')),
                if (item.unresolvedQuestionCount > 0)
                  Chip(
                    label: Text('${item.unresolvedQuestionCount} çözülemedi'),
                  ),
                if (item.reviewQuestionCount > 0)
                  Chip(label: Text('${item.reviewQuestionCount} tekrar')),
                if (item.correctQuestionCount > 0)
                  Chip(label: Text('${item.correctQuestionCount} doğru')),
                if (item.aiHelpCount > 0)
                  Chip(
                    avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text('${item.aiHelpCount} AI yardım'),
                  ),
                if (item.examSuccessRate != null)
                  Chip(
                    avatar: const Icon(Icons.quiz_outlined, size: 16),
                    label: Text(
                      'Sınav başarısı %${item.examSuccessRate!.round()}',
                    ),
                  ),
                if (item.examSuccessDelta != null &&
                    item.examSuccessDelta!.abs() >= 1)
                  Chip(
                    avatar: Icon(
                      item.examSuccessDelta! >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 16,
                    ),
                    label: Text(
                      'Konu trendi ${item.examSuccessDelta! >= 0 ? '+' : ''}'
                      '${item.examSuccessDelta!.toStringAsFixed(1)} puan',
                    ),
                  ),
                Chip(label: Text('Güven %${item.masteryConfidence}')),
              ],
            ),
            if (rate != null) ...[
              const SizedBox(height: 10),
              Text(
                'Çalışma tamamlama %${(rate * 100).round()} • ${item.completedStudyCount}/${item.plannedStudyCount}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (item.reasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text(
                  'Bu skor neden böyle?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                children: [
                  for (final reason in item.reasons)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text('• $reason'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({required this.study, required this.goals});

  final StudyAnalytics study;
  final GoalAnalytics goals;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _MetricRow(
              label: 'Program tamamlama',
              value: study.totalPlanCount == 0
                  ? 'Veri yok'
                  : '%${(study.completionRate * 100).round()}',
            ),
            const Divider(),
            _MetricRow(
              label: 'Tamamlanan plan',
              value: '${study.completedPlanCount}/${study.totalPlanCount}',
            ),
            const Divider(),
            _MetricRow(
              label: 'Hedef tamamlama',
              value: goals.total == 0
                  ? 'Veri yok'
                  : '%${(goals.completionRate * 100).round()}',
            ),
            if (goals.overduePending > 0) ...[
              const Divider(),
              _MetricRow(
                label: 'Geciken hedef',
                value: '${goals.overduePending}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard(this.item);

  final AnalyticsRecommendation item;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(child: Text('${item.priority}')),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(item.action),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Neden? ${item.reason}'),
          ),
          if (item.evidence.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final evidence in item.evidence)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('• $evidence'),
              ),
          ],
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard(this.item);

  final AnalyticsInsight item;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_toneIcon(item.tone)),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(item.detail),
      ),
    );
  }
}

class _EmptyAnalyticsView extends StatelessWidget {
  const _EmptyAnalyticsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 70),
        Icon(Icons.insights_rounded, size: 64),
        SizedBox(height: 18),
        Text(
          'Analiz için veri ekle',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 8),
        Text(
          'Sınav, zorlandığın soru, ders programı ve hedef kayıtları ekledikçe Analiz Merkezi gelişimini karşılaştıracak ve kanıta dayalı öneriler üretecek.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }
}

IconData _trendIcon(AnalyticsTrend trend) {
  return switch (trend) {
    AnalyticsTrend.improving => Icons.trending_up_rounded,
    AnalyticsTrend.declining => Icons.trending_down_rounded,
    AnalyticsTrend.stable => Icons.trending_flat_rounded,
    AnalyticsTrend.insufficient => Icons.more_horiz_rounded,
  };
}

IconData _toneIcon(AnalyticsInsightTone tone) {
  return switch (tone) {
    AnalyticsInsightTone.positive => Icons.check_circle_outline_rounded,
    AnalyticsInsightTone.neutral => Icons.info_outline_rounded,
    AnalyticsInsightTone.warning => Icons.warning_amber_rounded,
    AnalyticsInsightTone.critical => Icons.priority_high_rounded,
  };
}

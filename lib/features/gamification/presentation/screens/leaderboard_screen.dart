import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/gamification_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(gamificationSummaryProvider);
    final appUser = ref.watch(currentAppUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sıralama'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          Text(
            'Puanını takip et, serini koru ve ileride arkadaşlarınla yarış.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          summary.when(
            loading: () => const _ScoreLoadingCard(),
            error: (error, _) => _InfoCard(
              icon: Icons.error_outline_rounded,
              title: 'Puan bilgisi yüklenemedi',
              text: error.toString(),
            ),
            data: (value) => _MyScoreCard(
              name: appUser.valueOrNull?.displayName?.trim().isNotEmpty == true
                  ? appUser.valueOrNull!.displayName!
                  : 'Çalış 360 Öğrencisi',
              score: value.score,
              streak: value.currentStreak,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sıralama alanı',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.groups_2_outlined,
            title: 'Gerçek sıralama için sunucu kaydı hazırlanacak',
            text:
                'Şu anda puanın gerçek çalışma verilerinden hesaplanıyor. Global, bölge, okul ve arkadaş sıralamasını sahte veri göstermeden; sunucu tarafında güvenli puan kaydı eklendiğinde burada açacağız.',
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            icon: Icons.verified_user_outlined,
            title: 'Neden doğrudan liste göstermiyoruz?',
            text:
                'Puanın telefondan değiştirilememesi için leaderboard verisi istemci yerine doğrulanmış backend kaynağından gelmeli. Bu ekran buna hazır bırakıldı.',
          ),
        ],
      ),
    );
  }
}

class _MyScoreCard extends StatelessWidget {
  const _MyScoreCard({
    required this.name,
    required this.score,
    required this.streak,
  });

  final String name;
  final int score;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF6FF), Color(0xFFF2ECFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8E7F5), width: 1.35),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFF6C55E0),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$streak günlük seri',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFE46638),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1677B8),
                ),
              ),
              const Text('puan'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreLoadingCard extends StatelessWidget {
  const _ScoreLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF1685C8)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

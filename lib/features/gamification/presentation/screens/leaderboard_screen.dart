import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/gamification_summary.dart';
import '../../domain/leaderboard_entry.dart';
import '../providers/gamification_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(gamificationSummaryProvider);
    final appUser = ref.watch(currentAppUserProvider);
    final leaderboard = ref.watch(leaderboardEntriesProvider);
    ref.watch(leaderboardSyncProvider);

    final uid = appUser.valueOrNull?.uid;
    final name = appUser.valueOrNull?.displayName?.trim().isNotEmpty == true
        ? appUser.valueOrNull!.displayName!.trim()
        : 'Çalış 360 Öğrencisi';

    final rankValue = ref.watch(leaderboardRankProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sıralama')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(leaderboardSyncProvider);
          await ref.read(leaderboardSyncProvider.future);
          ref.invalidate(leaderboardRankProvider);
          ref.invalidate(leaderboardEntriesProvider);
          await Future.wait([
            ref.read(leaderboardRankProvider.future),
            ref.read(leaderboardEntriesProvider.future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            Text(
              'Puanın gerçek çalışma kayıtlarından hesaplanır. Eşit puanda önce en uzun seri, sonra doğru soru sayısı sıralamayı belirler.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 16),
            leaderboard.when(
              loading: () => summary.when(
                loading: () => const _ScoreLoadingCard(),
                error: (error, _) => _ErrorCard(error: error),
                data: (value) => _MyScoreCard(
                  name: name,
                  score: value.score,
                  streak: value.currentStreak,
                  longestStreak: value.longestStreak,
                  rank: rankValue.valueOrNull,
                ),
              ),
              error: (_, __) => summary.when(
                loading: () => const _ScoreLoadingCard(),
                error: (error, _) => _ErrorCard(error: error),
                data: (value) => _MyScoreCard(
                  name: name,
                  score: value.score,
                  streak: value.currentStreak,
                  longestStreak: value.longestStreak,
                  rank: rankValue.valueOrNull,
                ),
              ),
              data: (_) => summary.when(
                loading: () => const _ScoreLoadingCard(),
                error: (error, _) => _ErrorCard(error: error),
                data: (value) => _MyScoreCard(
                  name: name,
                  score: value.score,
                  streak: value.currentStreak,
                  longestStreak: value.longestStreak,
                  rank: rankValue.valueOrNull,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Genel sıralama',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const _TopBadge(),
              ],
            ),
            const SizedBox(height: 10),
            leaderboard.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _InfoCard(
                icon: Icons.cloud_off_rounded,
                title: 'Sıralama yüklenemedi',
                text:
                    'Leaderboard koleksiyonuna erişilemedi. Firestore yetkisini kontrol edip tekrar dene. Hata: $error',
              ),
              data: (entries) => entries.isEmpty
                  ? const _InfoCard(
                      icon: Icons.emoji_events_outlined,
                      title: 'Henüz sıralama oluşmadı',
                      text:
                          'İlk puan kaydı oluştuğunda öğrenciler burada puana göre listelenecek.',
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < entries.length; i++) ...[
                          _LeaderboardRow(
                            rank: i + 1,
                            entry: entries[i],
                            isMe: entries[i].uid == uid,
                          ),
                          if (i != entries.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            summary.maybeWhen(
              data: (value) => _ScoreRulesCard(summary: value),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}


class _MyScoreCard extends StatelessWidget {
  const _MyScoreCard({
    required this.name,
    required this.score,
    required this.streak,
    required this.longestStreak,
    required this.rank,
  });

  final String name;
  final int score;
  final int streak;
  final int longestStreak;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF2E6DC), Color(0xFFE7D7CC)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD6C5BB), width: 1.35),
      ),
      child: Column(
        children: [
          Row(
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
                  color: Color(0xFF1F4A3D),
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
                      '$streak günlük seri • en uzun $longestStreak gün',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF4A1F2C),
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
                          color: const Color(0xFF4A1F2C),
                        ),
                  ),
                  const Text('puan'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .78),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(Icons.leaderboard_rounded, color: Color(0xFF1F4A3D)),
                const SizedBox(width: 9),
                const Text(
                  'Genel sıran',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  rank == null ? 'Hesaplanıyor' : '#$rank',
                  style: const TextStyle(
                    color: Color(0xFF1F4A3D),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
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

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => Icons.workspace_premium_rounded,
      2 => Icons.military_tech_rounded,
      3 => Icons.military_tech_rounded,
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFE7D7CC) : Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: isMe ? const Color(0xFFB7A8F4) : const Color(0xFFD6C5BB),
          width: isMe ? 1.6 : 1.2,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: medal == null
                ? Text(
                    '#$rank',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  )
                : Icon(medal, color: const Color(0xFF4A1F2C), size: 26),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 7),
                      const _MeBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.currentStreak} gün seri • ${entry.correctCount} doğru • ${entry.examCount} deneme',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${entry.score}',
            style: const TextStyle(
              color: Color(0xFF4A1F2C),
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRulesCard extends StatelessWidget {
  const _ScoreRulesCard({required this.summary});

  final GamificationSummary summary;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.calculate_rounded,
      title: 'Puan nasıl hesaplanıyor?',
      text:
          'Doğru soru +10, yanlış soru +3, tekrar/bekleyen soru +1, tamamlanan AI çözümü +4, deneme +25, tamamlanan çalışma +10, tamamlanan hedef +10 ve her benzersiz aktif gün +5 puan. Şu ana kadar ${summary.activeDayCount} aktif gün, ${summary.completedStudyCount} tamamlanan çalışma ve ${summary.completedGoalCount} tamamlanan hedef kaydın var.',
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E6DC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'İlk 100',
        style: TextStyle(
          color: Color(0xFF4A1F2C),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MeBadge extends StatelessWidget {
  const _MeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1F4A3D).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'SEN',
        style: TextStyle(
          color: Color(0xFF1F4A3D),
          fontWeight: FontWeight.w900,
          fontSize: 9,
        ),
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.error_outline_rounded,
      title: 'Puan bilgisi yüklenemedi',
      text: error.toString(),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6C5BB), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF2E6DC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF4A1F2C)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
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
    );
  }
}

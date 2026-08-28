import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/study_data/presentation/providers/study_data_providers.dart';
import '../../models/hedef.dart';
import 'hedefler_ekle.dart';

class Hedefler extends ConsumerStatefulWidget {
  const Hedefler({super.key});

  @override
  ConsumerState<Hedefler> createState() => _HedeflerState();
}

class _HedeflerState extends ConsumerState<Hedefler> {
  String seciliFiltre = 'Hepsi';

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(hedefRepositoryProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Hedefler')),
      body: StreamBuilder<List<Hedef>>(
        stream: repository.getHedef(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const _StateMessage(
              icon: Icons.error_outline_rounded,
              title: 'Hedefler yüklenemedi',
              message: 'Bağlantını kontrol edip tekrar deneyebilirsin.',
            );
          }

          final hedefler = snapshot.data ?? const <Hedef>[];
          final filtrelenmis = hedefler
              .where(
                (hedef) =>
                    seciliFiltre == 'Hepsi' ||
                    hedef.hedefZamani == seciliFiltre,
              )
              .toList()
            ..sort((a, b) {
              if (a.tamamlandi != b.tamamlandi) {
                return a.tamamlandi ? 1 : -1;
              }
              return a.hedefTarihi.compareTo(b.hedefTarihi);
            });

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 250));
              if (mounted) setState(() {});
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _GoalsHero(hedefler: hedefler),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Hedeflerini yönet',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const HedeflerEkle(),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Yeni'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Günlük, haftalık ve aylık hedeflerini tek yerde takip et.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 14),
                        _FilterBar(
                          selected: seciliFiltre,
                          onChanged: (value) =>
                              setState(() => seciliFiltre = value),
                        ),
                      ],
                    ),
                  ),
                ),
                if (filtrelenmis.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _StateMessage(
                      icon: Icons.flag_outlined,
                      title: hedefler.isEmpty
                          ? 'Henüz hedef yok'
                          : 'Bu filtrede hedef yok',
                      message: hedefler.isEmpty
                          ? 'Kendine ulaşılabilir bir hedef belirleyerek başlayabilirsin.'
                          : 'Başka bir filtre seçebilir veya yeni hedef ekleyebilirsin.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    sliver: SliverList.separated(
                      itemCount: filtrelenmis.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final hedef = filtrelenmis[index];
                        return _GoalCard(
                          hedef: hedef,
                          onToggle: (value) async {
                            await repository.updateTamamlandi(
                              hedef.hedefId,
                              value,
                            );
                          },
                          onDelete: () => _deleteGoal(context, hedef),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HedeflerEkle()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Hedef Ekle'),
      ),
    );
  }

  Future<void> _deleteGoal(BuildContext context, Hedef hedef) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hedefi sil'),
        content: Text(
          '"${hedef.hedefAd}" hedefini silmek istediğine emin misin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (approved != true || !mounted) return;

    await ref.read(hedefRepositoryProvider).deleteHedef(hedef.hedefId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Hedef silindi.')));
  }
}

class _GoalsHero extends StatelessWidget {
  const _GoalsHero({required this.hedefler});

  final List<Hedef> hedefler;

  @override
  Widget build(BuildContext context) {
    final completed = hedefler.where((h) => h.tamamlandi).length;
    final active = hedefler.length - completed;
    final ratio = hedefler.isEmpty ? 0.0 : completed / hedefler.length;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1685C8), Color(0xFF6C55E0)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1685C8).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hedef İlerlemen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hedefler.isEmpty
                          ? 'İlk hedefini ekleyerek ritmini oluştur.'
                          : '$completed hedef tamamlandı, $active hedef devam ediyor.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(ratio * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _PeriodProgress(
                  label: 'Günlük',
                  goals: hedefler
                      .where((h) => h.hedefZamani == 'Günlük Hedef')
                      .toList(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PeriodProgress(
                  label: 'Haftalık',
                  goals: hedefler
                      .where((h) => h.hedefZamani == 'Haftalık Hedef')
                      .toList(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PeriodProgress(
                  label: 'Aylık',
                  goals: hedefler
                      .where((h) => h.hedefZamani == 'Aylık Hedef')
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodProgress extends StatelessWidget {
  const _PeriodProgress({required this.label, required this.goals});

  final String label;
  final List<Hedef> goals;

  @override
  Widget build(BuildContext context) {
    final completed = goals.where((h) => h.tamamlandi).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Text(
            '$completed/${goals.length}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const filters = <String, String>{
    'Hepsi': 'Tümü',
    'Günlük Hedef': 'Günlük',
    'Haftalık Hedef': 'Haftalık',
    'Aylık Hedef': 'Aylık',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((entry) {
          final active = selected == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: active,
              onSelected: (_) => onChanged(entry.key),
              showCheckmark: false,
              side: BorderSide(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: 1.25,
              ),
              labelStyle: TextStyle(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.hedef,
    required this.onToggle,
    required this.onDelete,
  });

  final Hedef hedef;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = hedef.hedefTarihi;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final accent = _goalColor(hedef.hedefZamani);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.22),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onToggle(!hedef.tamamlandi),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Checkbox(
                    value: hedef.tamamlandi,
                    onChanged: (value) {
                      if (value != null) onToggle(value);
                    },
                    side: BorderSide(color: accent, width: 1.7),
                    activeColor: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hedef.hedefAd,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              decoration: hedef.tamamlandi
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: hedef.tamamlandi
                                  ? colors.onSurfaceVariant
                                  : colors.onSurface,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _GoalTag(
                            icon: Icons.schedule_rounded,
                            text: hedef.hedefZamani
                                .replaceAll(' Hedef', '')
                                .trim(),
                            color: accent,
                          ),
                          _GoalTag(
                            icon: Icons.calendar_today_outlined,
                            text: dateText,
                            color: const Color(0xFF667085),
                          ),
                          if (hedef.tamamlandi)
                            const _GoalTag(
                              icon: Icons.check_circle_outline_rounded,
                              text: 'Tamamlandı',
                              color: Color(0xFF17895C),
                            ),
                        ],
                      ),
                      if (hedef.hedefNote.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          hedef.hedefNote.trim(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Hedefi sil',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _goalColor(String type) {
    if (type == 'Haftalık Hedef') return const Color(0xFF6C55E0);
    if (type == 'Aylık Hedef') return const Color(0xFFE6653C);
    return const Color(0xFF1685C8);
  }
}

class _GoalTag extends StatelessWidget {
  const _GoalTag({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 30,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/errors/auth_error_mapper.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/study_data/presentation/providers/study_data_providers.dart';
import '../../features/study_planner/presentation/screens/ai_study_planner_screen.dart';
import '../../models/dersProgrami.dart';
import '../../models/sinav_takvimi.dart';
import '../../widgets/ders_program_widget/takvim_widget.dart';
import 'dersprogrami_ekle.dart';
import 'sinav_takvimi_ekle.dart';

class Dersprogrami extends ConsumerStatefulWidget {
  const Dersprogrami({super.key});

  @override
  ConsumerState<Dersprogrami> createState() => _DersprogramiState();
}

class _DersprogramiState extends ConsumerState<Dersprogrami> {
  String seciliFiltre = 'Pazartesi';
  int seciliHafta = 1;

  static const _gunler = <String>[
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  Future<void> logout() async {
    final success = await ref.read(authControllerProvider.notifier).signOut();
    if (!context.mounted) return;

    if (success) {
      context.go(AppRoutes.login);
      return;
    }

    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthErrorMapper.message(state.error!))),
      );
    }
  }

  Future<void> _openExamCalendar() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SinavTakvimiEkle()));
  }

  Future<void> _openAddProgram() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DersprogramiEkle(initialWeekNumber: seciliHafta),
      ),
    );
  }

  Future<void> _openAiPlanner() async {
    final week = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => AiStudyPlannerScreen(initialWeekNumber: seciliHafta),
      ),
    );
    if (!mounted || week == null) return;
    setState(() => seciliHafta = week);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$week. hafta programın açıldı.')));
  }

  Future<void> _editProgram(DersProgram item) async {
    final dersController = TextEditingController(text: item.dersProgramDersAd);
    final konuController = TextEditingController(text: item.dersProgramKonuAd);
    final saatController = TextEditingController(
      text: item.dersProgramSaat.toString(),
    );
    final sureController = TextEditingController(
      text: item.durationMinutes.toString(),
    );
    var gun = item.dersProgramGun;
    var hafta = item.weekNumber;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Çalışmayı Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dersController,
                  decoration: const InputDecoration(labelText: 'Ders'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: konuController,
                  decoration: const InputDecoration(
                    labelText: 'Konu (isteğe bağlı)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: gun,
                  decoration: const InputDecoration(labelText: 'Gün'),
                  items: _gunler
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => gun = value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: hafta,
                  decoration: const InputDecoration(labelText: 'Hafta'),
                  items: List.generate(
                    52,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('${index + 1}. Hafta'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => hafta = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: saatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Başlangıç saati (0-23)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sureController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Süre (dakika)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (save == true && mounted) {
      final ders = dersController.text.trim();
      final saat = int.tryParse(saatController.text.trim());
      final sure = int.tryParse(sureController.text.trim());
      if (ders.isEmpty ||
          saat == null ||
          saat < 0 ||
          saat > 23 ||
          sure == null ||
          sure < 20 ||
          sure > 240) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ders, saat ve süre bilgilerini kontrol et.'),
          ),
        );
      } else {
        await ref
            .read(dersProgramiRepositoryProvider)
            .updateDersProgram(
              DersProgram(
                dersProgramId: item.dersProgramId,
                dersProgramSinavTur: item.dersProgramSinavTur,
                dersProgramDersAd: ders,
                dersProgramKonuAd: konuController.text.trim(),
                dersProgramGun: gun,
                dersProgramSaat: saat,
                tamamlandi: item.tamamlandi,
                durationMinutes: sure,
                source: item.source,
                weekNumber: hafta,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt,
              ),
            );
        if (mounted) {
          setState(() => seciliHafta = hafta);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Çalışma güncellendi.')));
        }
      }
    }

    dersController.dispose();
    konuController.dispose();
    saatController.dispose();
    sureController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Program'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: logout,
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: StreamBuilder<List<DersProgram>>(
        stream: ref.read(dersProgramiRepositoryProvider).getDersProgram(),
        builder: (context, programSnapshot) {
          final tumProgram = programSnapshot.data ?? const <DersProgram>[];
          final weeks =
              tumProgram.map((item) => item.weekNumber).toSet().toList()
                ..sort();
          if (weeks.isNotEmpty && !weeks.contains(seciliHafta)) {
            seciliHafta = weeks.last;
          }
          final selectedWeekItems = tumProgram
              .where((item) => item.weekNumber == seciliHafta)
              .toList(growable: false);
          final completed = selectedWeekItems
              .where((item) => item.tamamlandi)
              .length;
          final total = selectedWeekItems.length;
          final completionRate = total == 0 ? 0.0 : completed / total;
          final filter = seciliFiltre.trim().toLowerCase();
          final filtered =
              selectedWeekItems
                  .where((p) => p.dersProgramGun.trim().toLowerCase() == filter)
                  .toList(growable: false)
                ..sort(
                  (a, b) => a.dersProgramSaat.compareTo(b.dersProgramSaat),
                );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
            children: [
              _ProgramHero(
                total: total,
                completed: completed,
                completionRate: completionRate,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.auto_awesome_rounded,
                      label: 'AI Programı',
                      color: const Color(0xFF7A4FD8),
                      background: const Color(0xFFF2ECFF),
                      onTap: _openAiPlanner,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.add_task_rounded,
                      label: 'Çalışma Ekle',
                      color: const Color(0xFF1685C8),
                      background: const Color(0xFFEAF6FF),
                      onTap: _openAddProgram,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.event_note_rounded,
                label: 'Sınav Takvimi',
                color: const Color(0xFF6C55E0),
                background: const Color(0xFFF0ECFF),
                onTap: _openExamCalendar,
              ),
              const SizedBox(height: 24),
              const _SectionHeader(
                title: 'Sınav Takvimi',
                subtitle: 'Yaklaşan sınavlarını ay görünümünde takip et.',
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                decoration: _cardDecoration(
                  borderColor: const Color(0xFFD7D0F4),
                  shadowColor: const Color(0xFF6C55E0),
                ),
                child: StreamBuilder<List<SinavTakvimi>>(
                  stream: ref.read(sinavTakvimiRepositoryProvider).getDers(),
                  builder: (context, snapshot) {
                    final sinavlar = snapshot.data ?? const <SinavTakvimi>[];
                    return SinavTakvimiWidget(sinavlar: sinavlar);
                  },
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(
                title: 'Haftalık Program',
                subtitle: 'Gününü seç, çalışmalarını sırayla tamamla.',
              ),
              const SizedBox(height: 11),
              if (weeks.isNotEmpty) ...[
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: weeks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final week = weeks[index];
                      final selected = week == seciliHafta;
                      return ChoiceChip(
                        label: Text('$week. Hafta'),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => seciliHafta = week),
                        selectedColor: theme.colorScheme.secondary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected
                              ? theme.colorScheme.secondary
                              : const Color(0xFFD5E0E8),
                          width: 1.45,
                        ),
                        labelStyle: TextStyle(
                          color: selected
                              ? theme.colorScheme.onSecondary
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _gunler.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final gun = _gunler[index];
                    final selected = gun == seciliFiltre;
                    return ChoiceChip(
                      label: Text(gun),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => seciliFiltre = gun),
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected
                            ? theme.colorScheme.primary
                            : const Color(0xFFD5E0E8),
                        width: 1.45,
                      ),
                      labelStyle: TextStyle(
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _SelectedDaySummary(
                day: seciliFiltre,
                total: filtered.length,
                completed: filtered.where((item) => item.tamamlandi).length,
              ),
              const SizedBox(height: 12),
              if (programSnapshot.connectionState == ConnectionState.waiting)
                const _LoadingCard()
              else if (programSnapshot.hasError)
                _MessageCard(
                  message: 'Program yüklenemedi: ${programSnapshot.error}',
                )
              else if (filtered.isEmpty)
                _EmptyDayCard(day: seciliFiltre, onAdd: _openAddProgram)
              else
                Column(
                  children: [
                    for (var i = 0; i < filtered.length; i++) ...[
                      _ProgramCard(
                        item: filtered[i],
                        onEdit: () => _editProgram(filtered[i]),
                        onDelete: () async {
                          await ref
                              .read(dersProgramiRepositoryProvider)
                              .deleteDersProgram(filtered[i].dersProgramId);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Program silindi')),
                          );
                        },
                        onCompletedChanged: (value) async {
                          await ref
                              .read(dersProgramiRepositoryProvider)
                              .updateTamamlandi(
                                filtered[i].dersProgramId,
                                value,
                              );
                        },
                      ),
                      if (i != filtered.length - 1) const SizedBox(height: 11),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProgram,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Çalışma Ekle'),
      ),
    );
  }
}

class _ProgramHero extends StatelessWidget {
  const _ProgramHero({
    required this.total,
    required this.completed,
    required this.completionRate,
  });

  final int total;
  final int completed;
  final double completionRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (completionRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1685C8), Color(0xFF5C62D9)],
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFF0E72B0), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1685C8).withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: Colors.white),
              SizedBox(width: 9),
              Text(
                'Haftanı tek ekrandan yönet',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Planını tamamladıkça işaretle ve haftalık ilerlemeni takip et.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Planlanan',
                  value: '$total',
                  icon: Icons.list_alt_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroStat(
                  label: 'Tamamlanan',
                  value: '$completed',
                  icon: Icons.task_alt_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroStat(
                  label: 'İlerleme',
                  value: '%$percent',
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: completionRate,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1.55,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SelectedDaySummary extends StatelessWidget {
  const _SelectedDaySummary({
    required this.day,
    required this.total,
    required this.completed,
  });

  final String day;
  final int total;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final remaining = total - completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E3ED), width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.today_rounded,
              color: Color(0xFF1685C8),
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  total == 0
                      ? 'Bu gün için henüz çalışma eklenmemiş.'
                      : '$completed tamamlandı • $remaining kaldı',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (total > 0)
            Text(
              '$completed/$total',
              style: const TextStyle(
                color: Color(0xFF1685C8),
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onCompletedChanged,
  });

  final DersProgram item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onCompletedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = item.tamamlandi
        ? const Color(0xFF17895C)
        : const Color(0xFF1685C8);

    return Container(
      decoration: _cardDecoration(
        borderColor: accent.withValues(alpha: 0.28),
        shadowColor: accent,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 13, 7, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Checkbox(
                value: item.tamamlandi,
                activeColor: accent,
                onChanged: (value) {
                  if (value != null) onCompletedChanged(value);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.dersProgramDersAd,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            decoration: item.tamamlandi
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (item.tamamlandi)
                        const _StatusPill(
                          text: 'Tamamlandı',
                          color: Color(0xFF17895C),
                          background: Color(0xFFE9F8F1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.dersProgramKonuAd,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaPill(
                        icon: Icons.calendar_today_outlined,
                        text: item.dersProgramGun,
                      ),
                      _MetaPill(
                        icon: Icons.schedule_rounded,
                        text:
                            '${item.dersProgramSaat.toString().padLeft(2, '0')}:00',
                      ),
                      _MetaPill(
                        icon: Icons.school_outlined,
                        text: item.dersProgramSinavTur,
                      ),
                      _MetaPill(
                        icon: Icons.timer_outlined,
                        text: '${item.durationMinutes} dk',
                      ),
                      if (item.source == 'ai')
                        const _MetaPill(
                          icon: Icons.auto_awesome_rounded,
                          text: 'AI',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Düzenle',
                  color: theme.colorScheme.primary,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Sil',
                  color: theme.colorScheme.error,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0E7ED)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF667085)),
          const SizedBox(width: 5),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard({required this.day, required this.onAdd});

  final String day;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FF),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.event_available_outlined,
              size: 29,
              color: Color(0xFF1685C8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$day için çalışma yok',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Bu günü boş bırakabilir veya yeni bir çalışma ekleyebilirsin.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Çalışma ekle'),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
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
    borderRadius: BorderRadius.circular(21),
    border: Border.all(
      color: borderColor ?? const Color(0xFFD5E0E8),
      width: 1.6,
    ),
    boxShadow: [
      BoxShadow(
        color: shadow.withValues(alpha: 0.07),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/data_error_mapper.dart';
import '../../core/widgets/section_hero_card.dart';
import '../../features/study_data/presentation/providers/study_data_providers.dart';
import '../../models/sinav_takvimi.dart';

class SinavTakvimiEkle extends ConsumerStatefulWidget {
  const SinavTakvimiEkle({super.key});

  @override
  ConsumerState<SinavTakvimiEkle> createState() => _SinavTakvimiEkleState();
}

class _SinavTakvimiEkleState extends ConsumerState<SinavTakvimiEkle> {
  final List<String> sinavTurleri = ['TYT', 'AYT'];
  String? sinavTuru;
  DateTime? sinavZamani;
  bool _saving = false;

  Future<void> sinavEkle() async {
    if (_saving) return;
    if (sinavZamani == null || sinavTuru == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tür ve zamanı seçmelisin.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = ref.read(sinavTakvimiRepositoryProvider);
      final yeniSinavTakvimi = SinavTakvimi(
        sinavId: repository.createId(),
        sinavTur: sinavTuru!,
        sinavZamani: sinavZamani!,
      );
      await repository.addSinavProgram(yeniSinavTakvimi);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sınav takvime eklendi')));
      Navigator.pop(context, true);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(DataErrorMapper.message(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> tarihSec() async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (secilen != null && mounted) {
      setState(() => sinavZamani = secilen);
    }
  }

  String _dateLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Sınavı sil?'),
            content: const Text(
              'Bu sınav tarihi takvimden kaldırılacak. Bu işlem geri alınamaz.',
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
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final sinavlarAsync = ref.watch(sinavTakvimiProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sınav Takvimi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          const SectionHeroCard(
            icon: Icons.event_available_outlined,
            title: 'Yaklaşan sınavlarını ekle',
            subtitle:
                'TYT ve AYT tarihlerini kaydet; Program ekranında yaklaşan sınavlarını tek bakışta takip et.',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: sinavTuru,
                    decoration: const InputDecoration(
                      labelText: 'Sınav türü',
                      prefixIcon: Icon(Icons.assignment_outlined),
                    ),
                    items: sinavTurleri
                        .map(
                          (tur) =>
                              DropdownMenuItem(value: tur, child: Text(tur)),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => sinavTuru = value),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : tarihSec,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      sinavZamani == null
                          ? 'Tarih seç'
                          : _dateLabel(sinavZamani!),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : sinavEkle,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_rounded),
                      label: Text(_saving ? 'Ekleniyor...' : 'Takvime Ekle'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Kayıtlı sınavlar',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          sinavlarAsync.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: LinearProgressIndicator(),
              ),
            ),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(DataErrorMapper.message(error)),
              ),
            ),
            data: (sinavlar) {
              if (sinavlar.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Henüz takvime sınav eklenmemiş.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < sinavlar.length; i++) ...[
                    Card(
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            sinavlar[i].sinavTur,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        title: Text(
                          _dateLabel(sinavlar[i].sinavZamani),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text('Sınav tarihi'),
                        trailing: IconButton(
                          tooltip: 'Sil',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            final confirmed = await _confirmDelete();
                            if (!confirmed || !mounted) return;
                            try {
                              await ref
                                  .read(sinavTakvimiRepositoryProvider)
                                  .deleteSinav(sinavlar[i].sinavId);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sınav silindi')),
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(DataErrorMapper.message(error)),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    if (i != sinavlar.length - 1) const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

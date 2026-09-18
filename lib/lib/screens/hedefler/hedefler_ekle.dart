import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/data_error_mapper.dart';
import '../../features/study_data/presentation/providers/study_data_providers.dart';
import '../../models/hedef.dart';

class HedeflerEkle extends ConsumerStatefulWidget {
  const HedeflerEkle({super.key});

  @override
  ConsumerState<HedeflerEkle> createState() => _HedeflerEkleState();
}

class _HedeflerEkleState extends ConsumerState<HedeflerEkle> {
  static const hedefZamanlari = <String>[
    'Günlük Hedef',
    'Haftalık Hedef',
    'Aylık Hedef',
  ];

  final hedefText = TextEditingController();
  final hedefNoteText = TextEditingController();

  String? hedefZamani;
  DateTime? secilenTarih;
  bool _saving = false;

  @override
  void dispose() {
    hedefText.dispose();
    hedefNoteText.dispose();
    super.dispose();
  }

  Future<void> tarihSec() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: secilenTarih ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null && mounted) {
      setState(() => secilenTarih = picked);
    }
  }

  Future<void> hedefEkle() async {
    if (_saving) return;

    final hedefAdi = hedefText.text.trim();
    final hedefNotu = hedefNoteText.text.trim();

    if (hedefAdi.isEmpty || hedefZamani == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hedef adı ve hedef türü gerekli.')),
      );
      return;
    }

    if (hedefZamani != 'Günlük Hedef' && secilenTarih == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hedef tarihini seçmelisin.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = ref.read(hedefRepositoryProvider);
      final yeniHedef = Hedef(
        hedefId: repository.createId(),
        hedefAd: hedefAdi,
        hedefNote: hedefNotu,
        hedefTarihi: hedefZamani == 'Günlük Hedef'
            ? DateTime.now()
            : secilenTarih!,
        hedefZamani: hedefZamani!,
      );

      await repository.addHedef(yeniHedef);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hedef eklendi.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DataErrorMapper.message(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni hedef')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4A1F2C), Color(0xFF1F4A3D)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A1F2C).withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.flag_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Net bir hedef belirle',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kısa, ölçülebilir ve tamamladığında işaretleyebileceğin bir hedef oluştur.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.86),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.outlineVariant,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.045),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hedef detayları',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: hedefText,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Hedef',
                      hintText: 'Örn. 40 paragraf sorusu çöz',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hedefNoteText,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Not (isteğe bağlı)',
                      hintText: 'Hedefle ilgili kısa bir not ekle',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: hedefZamani,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Hedef türü',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                    items: hedefZamanlari
                        .map(
                          (zaman) => DropdownMenuItem(
                            value: zaman,
                            child: Text(zaman),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              hedefZamani = value;
                              if (value == 'Günlük Hedef') {
                                secilenTarih = null;
                              }
                            });
                          },
                  ),
                  if (hedefZamani == 'Haftalık Hedef' ||
                      hedefZamani == 'Aylık Hedef') ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _saving ? null : tarihSec,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Bitiş tarihi',
                          prefixIcon: Icon(Icons.event_available_outlined),
                          suffixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                        child: Text(
                          secilenTarih == null
                              ? 'Tarih seç'
                              : '${secilenTarih!.day.toString().padLeft(2, '0')}.${secilenTarih!.month.toString().padLeft(2, '0')}.${secilenTarih!.year}',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : hedefEkle,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_task_rounded),
              label: Text(_saving ? 'Kaydediliyor...' : 'Hedefi Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}

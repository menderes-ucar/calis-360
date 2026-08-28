import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/data_error_mapper.dart';
import '../../core/widgets/section_hero_card.dart';
import '../../features/study_data/presentation/providers/study_data_providers.dart';
import '../../models/sinav.dart';

class SinavEkle extends ConsumerStatefulWidget {
  const SinavEkle({super.key});

  @override
  ConsumerState<SinavEkle> createState() => _SinavEkleState();
}

class _SinavEkleState extends ConsumerState<SinavEkle> {
  final adController = TextEditingController();
  final Map<String, _SubjectControllers> _subjects = {};
  final Map<String, List<_TopicRowControllers>> _topicRows = {};

  String? secilenTur;
  String? secilenBrans;
  bool _saving = false;

  final List<String> sinavTuru = ['TYT', 'AYT'];
  final List<String> aytBrans = ['Sayısal', 'Eşit Ağırlık', 'Sözel', 'Dil'];

  final List<String> tytDersler = [
    'Türkçe',
    'Tarih',
    'Coğrafya',
    'Felsefe',
    'Din',
    'Matematik',
    'Fizik',
    'Kimya',
    'Biyoloji',
  ];

  final Map<String, List<String>> aytDersler = {
    'Sayısal': ['Matematik', 'Fizik', 'Kimya', 'Biyoloji'],
    'Eşit Ağırlık': ['Türkçe', 'Tarih', 'Coğrafya', 'Matematik'],
    'Sözel': ['Türkçe', 'Tarih', 'Coğrafya', 'Felsefe', 'Din'],
    'Dil': ['İngilizce', 'Almanca', 'Fransızca'],
  };

  @override
  void dispose() {
    adController.dispose();
    for (final controllers in _subjects.values) {
      controllers.dispose();
    }
    for (final rows in _topicRows.values) {
      for (final row in rows) {
        row.dispose();
      }
    }
    super.dispose();
  }

  List<String> get _aktifDersler {
    if (secilenTur == 'TYT') return tytDersler;
    if (secilenTur == 'AYT' && secilenBrans != null) {
      return aytDersler[secilenBrans] ?? const [];
    }
    return const [];
  }

  _SubjectControllers _controllersFor(String ders) =>
      _subjects.putIfAbsent(ders, _SubjectControllers.new);

  List<_TopicRowControllers> _rowsFor(String ders) =>
      _topicRows.putIfAbsent(ders, () => <_TopicRowControllers>[]);

  int? _parseOptionalInt(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  double? _parseOptionalDouble(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (adController.text.trim().isEmpty || secilenTur == null) {
      _showError('Lütfen sınav adı ve türü seçin.');
      return;
    }
    if (secilenTur == 'AYT' && secilenBrans == null) {
      _showError('AYT için branş seçmelisin.');
      return;
    }

    final netler = <String, double>{};
    final dersDetaylari = <String, SinavDersDetay>{};

    for (final ders in _aktifDersler) {
      final c = _controllersFor(ders);
      final dogru = _parseOptionalInt(c.dogru);
      final yanlis = _parseOptionalInt(c.yanlis);
      final bos = _parseOptionalInt(c.bos);
      final manualNet = _parseOptionalDouble(c.net);

      if ([dogru, yanlis, bos].whereType<int>().any((value) => value < 0)) {
        _showError('$ders için doğru, yanlış ve boş değerleri negatif olamaz.');
        return;
      }

      final hasQuestionDetail = dogru != null || yanlis != null || bos != null;
      if (!hasQuestionDetail && manualNet == null) continue;

      final d = dogru ?? 0;
      final y = yanlis ?? 0;
      final b = bos ?? 0;
      final calculatedNet = hasQuestionDetail ? d - (y / 4.0) : manualNet!;

      final topics = <String, SinavKonuDetay>{};
      for (final row in _rowsFor(ders)) {
        final topic = row.konu.text.trim();
        if (topic.isEmpty) continue;
        final td = _parseOptionalInt(row.dogru) ?? 0;
        final ty = _parseOptionalInt(row.yanlis) ?? 0;
        final tb = _parseOptionalInt(row.bos) ?? 0;
        if (td < 0 || ty < 0 || tb < 0) {
          _showError('$ders / $topic için değerler negatif olamaz.');
          return;
        }
        if (td + ty + tb == 0) continue;
        topics[topic] = SinavKonuDetay(dogru: td, yanlis: ty, bos: tb);
      }

      final topicQuestionCount = topics.values.fold<int>(
        0,
        (sum, item) => sum + item.toplam,
      );
      final subjectQuestionCount = d + y + b;
      if (hasQuestionDetail && topicQuestionCount > subjectQuestionCount) {
        _showError(
          '$ders konu kırılımındaki toplam soru sayısı ders toplamını geçemez.',
        );
        return;
      }

      netler[ders] = calculatedNet;
      if (hasQuestionDetail || topics.isNotEmpty) {
        dersDetaylari[ders] = SinavDersDetay(
          dogru: d,
          yanlis: y,
          bos: b,
          net: calculatedNet,
          konular: topics,
        );
      }
    }

    if (netler.isEmpty) {
      _showError('En az bir ders için net veya doğru/yanlış/boş bilgisi gir.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = ref.read(sinavRepositoryProvider);
      final yeniSinav = Sinav(
        sinavId: repository.createId(),
        sinavAd: adController.text.trim(),
        sinavTuru: secilenTur!,
        sinavBrans: secilenBrans,
        netler: netler,
        dersDetaylari: dersDetaylari,
      );
      await repository.addSinav(yeniSinav);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sınav başarıyla kaydedildi.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showError(DataErrorMapper.message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addTopicRow(String ders) {
    setState(() => _rowsFor(ders).add(_TopicRowControllers()));
  }

  void _removeTopicRow(String ders, int index) {
    setState(() {
      final rows = _rowsFor(ders);
      final removed = rows.removeAt(index);
      removed.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final aktifDersler = _aktifDersler;
    for (final ders in aktifDersler) {
      _controllersFor(ders);
      _rowsFor(ders);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sınav Ekle')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const SectionHeroCard(
              icon: Icons.analytics_outlined,
              title: 'Sınav sonucunu kaydet',
              subtitle:
                  'Netlerini, doğru-yanlışlarını ve konu kırılımlarını ekle; Analiz Merkezi gelişimini gerçek verilerle takip etsin.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: adController,
              decoration: const InputDecoration(
                labelText: 'Sınav adı',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.assignment_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: secilenTur,
              decoration: const InputDecoration(
                labelText: 'Sınav türü',
                border: OutlineInputBorder(),
              ),
              items: sinavTuru
                  .map((tur) => DropdownMenuItem(value: tur, child: Text(tur)))
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() {
                        secilenTur = value;
                        secilenBrans = null;
                      });
                    },
            ),
            if (secilenTur == 'AYT') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: secilenBrans,
                decoration: const InputDecoration(
                  labelText: 'Branş',
                  border: OutlineInputBorder(),
                ),
                items: aytBrans
                    .map(
                      (brans) =>
                          DropdownMenuItem(value: brans, child: Text(brans)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => secilenBrans = value),
              ),
            ],
            if (aktifDersler.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                'Ders sonuçları',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              for (final ders in aktifDersler)
                _SubjectExamCard(
                  subject: ders,
                  controllers: _controllersFor(ders),
                  topicRows: _rowsFor(ders),
                  onAddTopic: () => _addTopicRow(ders),
                  onRemoveTopic: (index) => _removeTopicRow(ders, index),
                ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Kaydediliyor...' : 'Sınavı Kaydet'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectExamCard extends StatelessWidget {
  const _SubjectExamCard({
    required this.subject,
    required this.controllers,
    required this.topicRows,
    required this.onAddTopic,
    required this.onRemoveTopic,
  });

  final String subject;
  final _SubjectControllers controllers;
  final List<_TopicRowControllers> topicRows;
  final VoidCallback onAddTopic;
  final ValueChanged<int> onRemoveTopic;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(
          subject,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text('Doğru / yanlış / boş veya yalnız net girişi'),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'Doğru',
                  controller: controllers.dogru,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  label: 'Yanlış',
                  controller: controllers.yanlis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(label: 'Boş', controller: controllers.bos),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controllers.net,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Net (detay girmiyorsan)',
              helperText:
                  'Doğru/yanlış/boş girildiğinde net otomatik hesaplanır.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Konu kırılımı',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: onAddTopic,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Konu ekle'),
              ),
            ],
          ),
          if (topicRows.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'İsteğe bağlı. Özellikle yanlış veya boş yaptığın konuları girersen konu başarı analizi çok daha güçlü olur.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (var i = 0; i < topicRows.length; i++) ...[
            const SizedBox(height: 8),
            _TopicRow(row: topicRows[i], onRemove: () => onRemoveTopic(i)),
          ],
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.row, required this.onRemove});

  final _TopicRowControllers row;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.konu,
                    decoration: const InputDecoration(
                      labelText: 'Konu adı',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Konu satırını sil',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Doğru',
                    controller: row.dogru,
                    dense: true,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NumberField(
                    label: 'Yanlış',
                    controller: row.yanlis,
                    dense: true,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NumberField(
                    label: 'Boş',
                    controller: row.bos,
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    this.dense = false,
  });

  final String label;
  final TextEditingController controller;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: dense,
      ),
    );
  }
}

class _SubjectControllers {
  final dogru = TextEditingController();
  final yanlis = TextEditingController();
  final bos = TextEditingController();
  final net = TextEditingController();

  void dispose() {
    dogru.dispose();
    yanlis.dispose();
    bos.dispose();
    net.dispose();
  }
}

class _TopicRowControllers {
  final konu = TextEditingController();
  final dogru = TextEditingController();
  final yanlis = TextEditingController();
  final bos = TextEditingController();

  void dispose() {
    konu.dispose();
    dogru.dispose();
    yanlis.dispose();
    bos.dispose();
  }
}

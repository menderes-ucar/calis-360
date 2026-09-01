
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../study_data/presentation/providers/study_data_providers.dart';
import '../../../question_media/application/question_image_optimizer.dart';
import '../../application/ai_solver_error_mapper.dart';
import '../../domain/ai_solution.dart';
import '../providers/ai_solver_providers.dart';

import '../../../../models/soru.dart';

class AiSolverScreen extends ConsumerStatefulWidget {
  const AiSolverScreen({super.key});

  @override
  ConsumerState<AiSolverScreen> createState() => _AiSolverScreenState();
}

class _AiSolverScreenState extends ConsumerState<AiSolverScreen> {
  static const _subjects = <String>[
    'Türkçe',
    'Matematik',
    'Geometri',
    'Tarih',
    'Coğrafya',
    'Felsefe',
    'Din',
    'Fizik',
    'Kimya',
    'Biyoloji',
    'Edebiyat',
  ];

  final _questionController = TextEditingController();
  final _topicController = TextEditingController();
  final _picker = ImagePicker();

  String _examScope = 'TYT';
  String _subject = 'Matematik';
  Uint8List? _imageBytes;
  String? _imageMimeType;
  String? _imageName;

  @override
  void dispose() {
    _questionController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (picked == null) return;

    final originalBytes = await picked.readAsBytes();

    OptimizedQuestionImage optimized;
    try {
      optimized = await QuestionImageOptimizer.optimize(originalBytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görsel hazırlanamadı. Başka bir görsel dene.'),
        ),
      );
      return;
    }

    debugPrint(
      '[AI_SOLVER] image ready '
      '${optimized.width}x${optimized.height} '
      '${optimized.optimizedBytes}B ${optimized.mimeType}',
    );

    if (!mounted) return;
    setState(() {
      _imageBytes = optimized.bytes;
      _imageMimeType = optimized.mimeType;
      _imageName = picked.name;
    });
  }

  Future<void> _solve() async {
    final question = _questionController.text.trim();
    if (question.isEmpty && _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soruyu yaz veya bir fotoğraf ekle.')),
      );
      return;
    }

    debugPrint(
      '[AI_SOLVER] solve pressed image=${_imageBytes?.lengthInBytes ?? 0}B '
      'mime=${_imageMimeType ?? '-'}',
    );

    final controller = ref.read(aiSolverControllerProvider.notifier);
    final result = await controller.solve(
      requestId: controller.createRequestId(),
      questionText: question,
      subject: _subject,
      topic: _topicController.text.trim(),
      examScope: _examScope,
      imageBytes: _imageBytes,
      imageMimeType: _imageMimeType,
    );

    if (!mounted || result != null) return;
    final state = ref.read(aiSolverControllerProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AiSolverErrorMapper.message(state.error!))),
      );
    }
  }

  Future<void> _saveSolution(AiSolution solution) async {
    final repository = ref.read(soruRepositoryProvider);
    final question = solution.recognizedQuestion.trim().isNotEmpty
        ? solution.recognizedQuestion.trim()
        : _questionController.text.trim();

    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilecek soru metni bulunamadı.')),
      );
      return;
    }

    try {
      final soru = Soru(
        soruId: repository.createId(),
        soruAd: question,
        soruDers: solution.subject.isEmpty ? _subject : solution.subject,
        soruKonu: solution.topic.isEmpty
            ? _topicController.text.trim()
            : solution.topic,
        soruCevap: solution.finalAnswer,
        soruDurum: 'needs_review',
        source: 'ai_saved',
        aiRequestId: solution.requestId,
      );
      await repository.addSoru(soru);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI çözümü Sorularım bölümüne kaydedildi.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Soru kaydedilemedi: $error')));
    }
  }

  void _newQuestion() {
    ref.read(aiSolverControllerProvider.notifier).clear();
    setState(() {
      _questionController.clear();
      _topicController.clear();
      _imageBytes = null;
      _imageMimeType = null;
      _imageName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiSolverControllerProvider);
    final history = ref.watch(aiHistoryProvider);
    final solution = state.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Soru Çözücü'),
        actions: [
          IconButton(
            onPressed: state.isLoading ? null : _newQuestion,
            tooltip: 'Yeni soru',
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _buildIntroCard(context),
          const SizedBox(height: 16),
          _buildQuestionCard(context, state.isLoading),
          if (state.isLoading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(
              child: Text('Soru analiz ediliyor ve çözüm hazırlanıyor...'),
            ),
          ],
          if (solution != null) ...[
            const SizedBox(height: 20),
            _SolutionCard(
              solution: solution,
              onSave: () => _saveSolution(solution),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Son AI Çözümlerim',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          history.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text(
              'Geçmiş yüklenemedi: ${AiSolverErrorMapper.message(error)}',
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Henüz tamamlanmış AI çözümün yok.'),
                  ),
                );
              }
              return Column(
                children: items
                    .take(8)
                    .map(
                      (item) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.auto_awesome_rounded),
                          ),
                          title: Text(
                            item.recognizedQuestion.isNotEmpty
                                ? item.recognizedQuestion
                                : '${item.subject} • ${item.topic}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item.finalAnswer,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => DraggableScrollableSheet(
                              expand: false,
                              initialChildSize: 0.85,
                              minChildSize: 0.5,
                              maxChildSize: 0.95,
                              builder: (context, controller) => ListView(
                                controller: controller,
                                padding: const EdgeInsets.all(16),
                                children: [
                                  _SolutionCard(
                                    solution: item,
                                    onSave: () => _saveSolution(item),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A1F2C), Color(0xFF1F4A3D)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x241685C8), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 29),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Soruyu bırak, çözümü birlikte açalım',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('Metin veya fotoğraf ekle; Çalış 360 sana adım adım çözüm ve konu özeti hazırlasın.',
                  style: TextStyle(color: Color(0xE6FFFFFF), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, bool loading) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFD6C5BB), width: 1.7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _examScope,
                    decoration: const InputDecoration(
                      labelText: 'Sınav',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TYT', child: Text('TYT')),
                      DropdownMenuItem(value: 'AYT', child: Text('AYT')),
                    ],
                    onChanged: loading
                        ? null
                        : (value) =>
                              setState(() => _examScope = value ?? 'TYT'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _subject,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ders',
                      border: OutlineInputBorder(),
                    ),
                    items: _subjects
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: loading
                        ? null
                        : (value) =>
                              setState(() => _subject = value ?? 'Matematik'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicController,
              enabled: !loading,
              decoration: const InputDecoration(
                labelText: 'Konu (isteğe bağlı)',
                hintText: 'Örn. Türev, Paragraf, Elektrik...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              enabled: !loading,
              minLines: 4,
              maxLines: 9,
              decoration: const InputDecoration(
                labelText: 'Soruyu yaz',
                hintText: 'Soru metnini buraya yazabilirsin...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  _imageBytes!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _imageName ?? 'Soru görseli',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: loading
                        ? null
                        : () => setState(() {
                            _imageBytes = null;
                            _imageMimeType = null;
                            _imageName = null;
                          }),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Görseli kaldır',
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: loading ? null : _solve,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text(
                  'AI ile Çöz',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kullanım hakkı ve kredi kontrolü sunucuda yapılır; '
              'uygulamayı değiştirerek ücretsiz AI kullanımı açılamaz.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SolutionCard extends StatelessWidget {
  const _SolutionCard({required this.solution, required this.onSave});

  final AiSolution solution;
  final VoidCallback onSave;

  Color _confidenceColor(BuildContext context) {
    switch (solution.confidence) {
      case 'high':
        return Colors.green;
      case 'low':
        return Theme.of(context).colorScheme.error;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFD6C5BB), width: 1.7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'AI Çözümü',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                Chip(
                  avatar: Icon(
                    Icons.circle,
                    size: 10,
                    color: _confidenceColor(context),
                  ),
                  label: Text('Güven: ${solution.confidence}'),
                ),
              ],
            ),
            if (solution.recognizedQuestion.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Algılanan soru',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              SelectableText(solution.recognizedQuestion),
            ],
            const SizedBox(height: 16),
            Text(
              'Kısa cevap',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            SelectableText(solution.shortAnswer),
            const Divider(height: 28),
            Text(
              'Adım adım çözüm',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...solution.steps.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 14, child: Text('${entry.key + 1}')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.value.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          SelectableText(entry.value.explanation),
                          if (entry.value.expression.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            SelectableText(
                              entry.value.expression,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 28),
            Text(
              'Sonuç',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            SelectableText(
              solution.finalAnswer,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (solution.conceptSummary.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Konu özeti',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              SelectableText(solution.conceptSummary),
            ],
            if (solution.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...solution.warnings.map(
                (warning) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: Text(warning),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    solution.usedCredit
                        ? '${solution.creditCost} kredi kullanıldı • kalan ${solution.remainingCredits}'
                        : 'Bu çözüm dahil kullanım hakkından karşılandı',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Sorularıma Kaydet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/router.dart';
import '../../core/errors/data_error_mapper.dart';
import '../../core/widgets/section_hero_card.dart';
import '../../features/question_media/application/question_image_optimizer.dart';
import '../../features/study_data/presentation/providers/study_data_providers.dart';
import '../../models/soru.dart';

class SoruEkle extends ConsumerStatefulWidget {
  const SoruEkle({super.key});

  @override
  ConsumerState<SoruEkle> createState() => _SoruEkleState();
}

class _SoruEkleState extends ConsumerState<SoruEkle> {
  static const dersler = <String>[
    'Türkçe',
    'Tarih',
    'Coğrafya',
    'Felsefe',
    'Din',
    'Matematik',
    'Geometri',
    'Fizik',
    'Kimya',
    'Biyoloji',
  ];

  static const _durumEtiketleri = <String, String>{
    'unresolved': 'Çözemedim',
    'wrong': 'Yanlış yaptım',
    'needs_review': 'Tekrar etmeliyim',
    'correct': 'Doğru çözdüm',
  };

  final konuController = TextEditingController();
  final soruController = TextEditingController();
  final cevapController = TextEditingController();
  final _picker = ImagePicker();

  String? secilenDers;
  String _secilenDurum = 'unresolved';
  Uint8List? _imageBytes;
  bool _saving = false;
  bool _preparingImage = false;

  @override
  void dispose() {
    konuController.dispose();
    soruController.dispose();
    cevapController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_saving || _preparingImage) return;
    setState(() => _preparingImage = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2200,
        maxHeight: 2200,
      );
      if (picked == null) return;
      final optimized = await QuestionImageOptimizer.optimize(
        await picked.readAsBytes(),
      );
      if (!mounted) return;
      setState(() => _imageBytes = optimized.bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görsel hazırlanamadı. Başka bir görsel dene.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _preparingImage = false);
    }
  }

  Future<void> _chooseImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Fotoğraf çek'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeriden seç'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (secilenDers == null ||
        konuController.text.trim().isEmpty ||
        (soruController.text.trim().isEmpty && _imageBytes == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ders, konu ve soru metni veya soru görseli gerekli.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    String? uploadedUrl;
    String? createdId;

    try {
      final repository = ref.read(soruRepositoryProvider);
      createdId = repository.createId();

      if (_imageBytes != null) {
        uploadedUrl = await ref
            .read(questionMediaRepositoryProvider)
            .uploadQuestionImage(questionId: createdId, bytes: _imageBytes!);
      }

      final yeniSoru = Soru(
        soruId: createdId,
        soruAd: soruController.text.trim().isEmpty
            ? 'Görsel soru'
            : soruController.text.trim(),
        soruDers: secilenDers!,
        soruKonu: konuController.text.trim(),
        soruCevap: cevapController.text.trim(),
        soruDurum: _secilenDurum,
        source: 'manual',
        imageUrl: uploadedUrl,
      );

      await repository.addSoru(yeniSoru);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soru başarıyla kaydedildi')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (uploadedUrl != null && createdId != null) {
        await ref
            .read(questionMediaRepositoryProvider)
            .deleteQuestionImage(createdId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(DataErrorMapper.message(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Soru Ekle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SectionHeroCard(
            icon: Icons.bookmark_add_outlined,
            title: 'Zorlandığın soruyu kaydet',
            subtitle:
                'Soruyu yaz, fotoğrafını ekle ve daha sonra tekrar çözmek için arşivine kaydet.',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: secilenDers,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Ders'),
                    items: dersler
                        .map(
                          (ders) =>
                              DropdownMenuItem(value: ders, child: Text(ders)),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => secilenDers = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: konuController,
                    decoration: const InputDecoration(
                      labelText: 'Konu',
                      hintText: 'Örn. Problemler, Paragraf, Elektrik',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _secilenDurum,
                    decoration: const InputDecoration(
                      labelText: 'Bu sorudaki durumun',
                    ),
                    items: _durumEtiketleri.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _secilenDurum = value);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: soruController,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: 'Soru metni',
                      hintText: _imageBytes == null
                          ? 'Soruyu yaz veya aşağıdan görsel ekle'
                          : 'İstersen görsele ek açıklama yaz',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _saving ? null : _chooseImageSource,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 116),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: _imageBytes == null
                          ? Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  Icon(
                                    _preparingImage
                                        ? Icons.hourglass_top_rounded
                                        : Icons.add_a_photo_outlined,
                                    size: 30,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _preparingImage
                                        ? 'Görsel hazırlanıyor...'
                                        : 'Fotoğraf çek veya galeriden seç',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Görsel yüklenmeden önce otomatik küçültülür.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Stack(
                                children: [
                                  Image.memory(
                                    _imageBytes!,
                                    width: double.infinity,
                                    height: 220,
                                    fit: BoxFit.contain,
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: IconButton.filled(
                                      tooltip: 'Görseli kaldır',
                                      onPressed: _saving
                                          ? null
                                          : () => setState(
                                              () => _imageBytes = null,
                                            ),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cevapController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Cevap / not (isteğe bağlı)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Kaydediliyor...' : 'Soruyu Kaydet'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => context.push(AppRoutes.aiSolver),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Bu soruyu AI ile çöz'),
          ),
        ],
      ),
    );
  }
}

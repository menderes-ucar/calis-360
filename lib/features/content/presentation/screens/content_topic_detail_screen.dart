import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../core/widgets/async_state_view.dart';
import '../../../billing/presentation/providers/billing_providers.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';
import '../../domain/content_models.dart';
import '../providers/audio_lesson_providers.dart';
import '../providers/content_providers.dart';

const _ink = Color(0xFF2B2022);
const _border = Color(0xFFD8E1EA);
const _primary = Color(0xFF4A1F2C);
const _secondary = Color(0xFF1F4A3D);

class ContentTopicDetailScreen extends ConsumerWidget {
  const ContentTopicDetailScreen({
    super.key,
    required this.subjectId,
    required this.unitId,
    required this.topicId,
  });

  final String subjectId;
  final String unitId;
  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = TopicDetailArgs(
      subjectId: subjectId,
      unitId: unitId,
      topicId: topicId,
    );

    final topic = ref.watch(topicDetailProvider(args));

    ref.listen<AsyncValue<StudyTopic?>>(topicDetailProvider(args), (
      previous,
      next,
    ) {
      final loaded = next.valueOrNull;

      if (loaded == null) return;
      if (previous?.valueOrNull?.id == loaded.id) return;

      unawaited(
        ref
            .read(gamificationRepositoryProvider)
            .recordActivity(type: 'topic_read')
            .catchError((_) {}),
      );
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Konu Özeti')),
      body: AsyncStateView<StudyTopic?>(
        value: topic,
        isEmpty: (value) => value == null,
        empty: const _ContentEmptyState(
          title: 'Konu bulunamadı',
          message: 'Bu içerik kaldırılmış veya henüz hazır olmayabilir.',
        ),
        onRetry: () {
          ref.invalidate(topicDetailProvider(args));
        },
        data: (value) => _TopicBody(topic: value!),
      ),
    );
  }
}

class _TopicBody extends ConsumerWidget {
  const _TopicBody({required this.topic});

  final StudyTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personalArgs = PersonalSummaryArgs(
      subjectId: topic.subjectId,
      unitId: topic.unitId,
      topicId: topic.id,
    );

    final personalSummary = ref.watch(personalSummaryProvider(personalArgs));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      children: [
        _TopicHero(topic: topic),
        const SizedBox(height: 4),
        if (!topic.isPublished) const _DraftNotice(),
        _AudioPreviewCard(topic: topic),
        if (topic.learningObjectives.isNotEmpty)
          _SectionCard(
            icon: Icons.track_changes_rounded,
            title: 'Bu konuda ne öğreneceksin?',
            child: _BulletList(items: topic.learningObjectives),
          ),
        personalSummary.when(
          loading: () => _SectionCard(
            icon: Icons.menu_book_rounded,
            title: 'Özet',
            child: Text(topic.summary, style: const TextStyle(height: 1.65)),
          ),
          error: (_, __) => _SummaryCard(
            topic: topic,
            personalSummary: null,
            onChanged: () {
              ref.invalidate(personalSummaryProvider(personalArgs));
            },
          ),
          data: (value) => _SummaryCard(
            topic: topic,
            personalSummary: value,
            onChanged: () {
              ref.invalidate(personalSummaryProvider(personalArgs));
            },
          ),
        ),
        if (topic.keyPoints.isNotEmpty)
          _SectionCard(
            icon: Icons.bolt_rounded,
            title: 'Kritik Noktalar',
            child: _BulletList(items: topic.keyPoints),
          ),
        if (topic.formulas.isNotEmpty)
          _SectionCard(
            icon: Icons.functions_rounded,
            title: 'Formüller',
            child: Column(
              children: topic.formulas
                  .map((item) => _FormulaBox(text: item))
                  .toList(growable: false),
            ),
          ),
        if (topic.commonMistakes.isNotEmpty)
          _SectionCard(
            icon: Icons.warning_amber_rounded,
            title: 'Sık Yapılan Hatalar',
            child: _BulletList(items: topic.commonMistakes),
          ),
        if (topic.examples.isNotEmpty)
          _SectionCard(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Örnekler',
            child: Column(
              children: topic.examples
                  .map((example) => _ExampleCard(example: example))
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }
}

class _TopicHero extends StatelessWidget {
  const _TopicHero({required this.topic});

  final StudyTopic topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x201685C8),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.menu_book_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 14),
          Text(
            topic.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (topic.shortDescription.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              topic.shortDescription,
              style: const TextStyle(color: Color(0xE8FFFFFF), height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...topic.examScopes.map((e) => _HeroChip(text: e)),
              _HeroChip(text: '${topic.estimatedReadMinutes} dk okuma'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x2AFFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({
    required this.topic,
    required this.personalSummary,
    required this.onChanged,
  });

  final StudyTopic topic;
  final String? personalSummary;
  final VoidCallback onChanged;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kendi özetini kaydetmek için giriş yapmalısın.'),
        ),
      );
      return;
    }

    final controller = TextEditingController(
      text: personalSummary ?? topic.summary,
    );

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kendi özetin',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bu değişiklik yalnızca senin hesabında görünür. '
                  'Orijinal konu içeriği değişmez.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  minLines: 7,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    hintText: 'Kendi çalışma özetini yaz...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (personalSummary != null)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext, 'reset');
                        },
                        child: const Text('Orijinale dön'),
                      ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext, 'save:${controller.text}');
                      },
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (action == null || !context.mounted) {
      return;
    }

    final repository = ref.read(contentRepositoryProvider);

    try {
      if (action == 'reset') {
        await repository.deletePersonalSummary(
          uid: uid,
          subjectId: topic.subjectId,
          unitId: topic.unitId,
          topicId: topic.id,
        );
      } else if (action.startsWith('save:')) {
        await repository.savePersonalSummary(
          uid: uid,
          subjectId: topic.subjectId,
          unitId: topic.unitId,
          topicId: topic.id,
          summary: action.substring(5),
        );
      }

      onChanged();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'reset'
                  ? 'Orijinal özete dönüldü.'
                  : 'Kendi özetin kaydedildi.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Özet kaydedilemedi: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = personalSummary ?? topic.summary;

    return _SectionCard(
      icon: Icons.menu_book_rounded,
      title: 'Özet',
      trailing: TextButton.icon(
        onPressed: () {
          _edit(context, ref);
        },
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(personalSummary == null ? 'Kendi özetini yaz' : 'Düzenle'),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: _ink),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (personalSummary != null) ...[
              const _PersonalBadge(),
              const SizedBox(height: 10),
            ],
            Text(shown, style: const TextStyle(height: 1.65)),
          ],
        ),
      ),
    );
  }
}

class _PersonalBadge extends StatelessWidget {
  const _PersonalBadge();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFFF2E6DC),
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          'KİŞİSEL ÖZET',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _AudioPreviewCard extends ConsumerStatefulWidget {
  const _AudioPreviewCard({required this.topic});

  final StudyTopic topic;

  @override
  ConsumerState<_AudioPreviewCard> createState() {
    return _AudioPreviewCardState();
  }
}

class _AudioPreviewCardState extends ConsumerState<_AudioPreviewCard> {
  late final FlutterTts _tts;

  bool _authorizing = false;
  bool _playing = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();

    _tts = FlutterTts();

    _tts.setStartHandler(() {
      if (!mounted) return;

      setState(() {
        _playing = true;
        _paused = false;
      });
    });

    _tts.setCompletionHandler(() {
      if (!mounted) return;

      setState(() {
        _playing = false;
        _paused = false;
      });
    });

    _tts.setCancelHandler(() {
      if (!mounted) return;

      setState(() {
        _playing = false;
        _paused = false;
      });
    });

    _tts.setPauseHandler(() {
      if (!mounted) return;

      setState(() {
        _playing = false;
        _paused = true;
      });
    });

    _tts.setContinueHandler(() {
      if (!mounted) return;

      setState(() {
        _playing = true;
        _paused = false;
      });
    });

    _tts.setErrorHandler((message) {
      if (!mounted) return;

      setState(() {
        _playing = false;
        _paused = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ses motoru hatası: $message')));
    });

    unawaited(_configureTts());
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.47);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _start() async {
    if (_authorizing || _playing || _paused) {
      return;
    }

    if (!widget.topic.hasNarration) {
      return;
    }

    setState(() {
      _authorizing = true;
    });

    try {
      final authorization = await ref
          .read(audioLessonRepositoryProvider)
          .authorize(
            subjectId: widget.topic.subjectId,
            unitId: widget.topic.unitId,
            topicId: widget.topic.id,
          );

      if (!mounted) return;

      await _tts.stop();

      final result = await _tts.speak(widget.topic.narrationText);

      if (result != 1) {
        throw StateError('Ses motoru başlatılamadı.');
      }

      if (authorization.creditCost > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${authorization.creditCost} kredi kullanıldı • '
              'kalan ${authorization.creditBalance} kredi',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_functionErrorMessage(error))));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sesli özet başlatılamadı: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _authorizing = false;
        });
      }
    }
  }

  Future<void> _pause() async {
    if (!_playing) return;

    try {
      final result = await _tts.pause();

      if (result != 1 && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ses duraklatılamadı.')));
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ses duraklatılamadı: $error')));
    }
  }

  Future<void> _resume() async {
    if (!_paused || _authorizing) {
      return;
    }

    try {
      /*
       * Burada tekrar authorize çağrısı YOK.
       * Aynı dinleme oturumuna devam ediyoruz.
       *
       * flutter_tts Android pause uygulaması,
       * pause konumunu kendi içinde tutar ve aynı
       * FlutterTts instance'ında yeniden speak()
       * çağrıldığında kalan metinden devam eder.
       */
      final result = await _tts.speak(widget.topic.narrationText);

      if (result != 1) {
        throw StateError('Sesli özete devam edilemedi.');
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sesli özete devam edilemedi: $error')),
      );
    }
  }

  Future<void> _stop() async {
    try {
      await _tts.stop();
    } finally {
      if (mounted) {
        setState(() {
          _playing = false;
          _paused = false;
        });
      }
    }
  }

  String _functionErrorMessage(FirebaseFunctionsException error) {
    final details = error.details;

    if (details is Map) {
      final reason = details['reason']?.toString();

      if (reason == 'insufficient_credits') {
        return 'Bu dersi dinlemek için 3 kredi gerekiyor.';
      }

      if (reason == 'rate_limited') {
        return 'Çok hızlı tekrar denedin. Birkaç saniye sonra tekrar dene.';
      }
    }

    switch (error.code) {
      case 'unauthenticated':
        return 'Sesli özeti dinlemek için giriş yapmalısın.';

      case 'not-found':
        return 'Sesli ders içeriği bulunamadı.';

      case 'failed-precondition':
        return error.message ?? 'Bu sesli ders henüz hazır değil.';

      case 'resource-exhausted':
        return error.message ?? 'Bu işlem şu anda gerçekleştirilemiyor.';

      default:
        return error.message ?? 'Sesli özet başlatılamadı.';
    }
  }

  @override
  void dispose() {
    unawaited(_tts.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final premium =
        ref.watch(billingControllerProvider).status?.subscription.active ==
        true;

    return _SectionCard(
      icon: Icons.headphones_rounded,
      title: 'Sesli özet',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.topic.hasNarration
                ? 'Dersin özetini dinle. Konuyu ekrandan takip ederken '
                      'sesli özetle hızlı tekrar yapabilirsin.'
                : 'Bu dersin sesli özeti hazırlanıyor.',
            style: const TextStyle(height: 1.5),
          ),
          if (widget.topic.hasNarration) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaChip(
                  text: premium
                      ? 'Premium • sınırsız'
                      : '${widget.topic.audioCreditCost} kredi / dinleme',
                ),
                if (_authorizing)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                else if (_playing)
                  FilledButton.icon(
                    onPressed: _pause,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.pause_rounded),
                    label: const Text('Duraklat'),
                  )
                else if (_paused)
                  FilledButton.icon(
                    onPressed: _resume,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Devam Et'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _start,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Dinlemeye Başla'),
                  ),
                if (_playing || _paused)
                  OutlinedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Durdur'),
                  ),
              ],
            ),
            if (_paused) ...[
              const SizedBox(height: 10),
              const Text(
                'Dinleme duraklatıldı. “Devam Et” ile aynı '
                'oturumdan devam edebilirsin; tekrar kredi kesilmez.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF74676A),
                  height: 1.4,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1.7),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2E6DC),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: _primary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border, width: 1.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _FormulaBox extends StatelessWidget {
  const _FormulaBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E6DC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, width: 1.4),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45),
      ),
    );
  }
}

class _DraftNotice extends StatelessWidget {
  const _DraftNotice();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      icon: Icons.construction_rounded,
      title: 'İçerik hazırlanıyor',
      child: Text(
        'Bu konu katalogda mevcut ancak ayrıntılı içerik '
        'kalite kontrolünden henüz geçmedi.',
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 6, color: _ink),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item, style: const TextStyle(height: 1.5)),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.example});

  final StudyExample example;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E6DC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SORU',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            example.question,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const Divider(height: 24),
          const Text(
            'ÇÖZÜM',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(example.solution, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}

class _ContentEmptyState extends StatelessWidget {
  const _ContentEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                color: colors.primary,
                size: 29,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

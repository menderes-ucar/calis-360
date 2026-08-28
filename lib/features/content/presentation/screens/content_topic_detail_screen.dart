import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_state_view.dart';
import '../../../billing/presentation/providers/billing_providers.dart';
import '../../domain/content_models.dart';
import '../providers/content_providers.dart';

const _ink = Color(0xFF172033);
const _border = Color(0xFFD8E1EA);
const _primary = Color(0xFF1685C8);
const _secondary = Color(0xFF6C55E0);

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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Konu Özeti')),
      body: AsyncStateView<StudyTopic?>(
        value: topic,
        isEmpty: (value) => value == null,
        empty: const _ContentEmptyState(title: 'Konu bulunamadı', message: 'Bu içerik kaldırılmış veya henüz hazır olmayabilir.'),
        onRetry: () => ref.invalidate(topicDetailProvider(args)),
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
            onChanged: () =>
                ref.invalidate(personalSummaryProvider(personalArgs)),
          ),
          data: (value) => _SummaryCard(
            topic: topic,
            personalSummary: value,
            onChanged: () =>
                ref.invalidate(personalSummaryProvider(personalArgs)),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [_primary, _secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(color: Color(0x201685C8), blurRadius: 20, offset: Offset(0, 8)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.menu_book_rounded, color: Colors.white, size: 30),
        const SizedBox(height: 14),
        Text(topic.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        if (topic.shortDescription.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(topic.shortDescription, style: const TextStyle(color: Color(0xE8FFFFFF), height: 1.4)),
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: const Color(0x2AFFFFFF), borderRadius: BorderRadius.circular(999)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
  );
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
      builder: (sheetContext) => Padding(
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
                'Bu değişiklik yalnızca senin hesabında görünür. Orijinal konu içeriği değişmez.',
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
                      onPressed: () => Navigator.pop(sheetContext, 'reset'),
                      child: const Text('Orijinale dön'),
                    ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () =>
                        Navigator.pop(sheetContext, 'save:${controller.text}'),
                    child: const Text('Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (action == null || !context.mounted) return;

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
        onPressed: () => _edit(context, ref),
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
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: Color(0xFFEAF6FF),
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
          BoxShadow(color: Color(0x10000000), blurRadius: 16, offset: Offset(0, 6)),
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
                  color: const Color(0xFFEAF6FF),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border, width: 1.4),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _FormulaBox extends StatelessWidget {
  const _FormulaBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border, width: 1.4),
    ),
    child: SelectableText(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45),
    ),
  );
}

class _DraftNotice extends StatelessWidget {
  const _DraftNotice();
  @override
  Widget build(BuildContext context) => _SectionCard(
    icon: Icons.construction_rounded,
    title: 'İçerik hazırlanıyor',
    child: const Text(
      'Bu konu katalogda mevcut ancak ayrıntılı içerik kalite kontrolünden henüz geçmedi.',
    ),
  );
}

class _AudioPreviewCard extends ConsumerWidget {
  const _AudioPreviewCard({required this.topic});
  final StudyTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium =
        ref.watch(billingControllerProvider).status?.subscription.active ==
        true;
    return _SectionCard(
      icon: Icons.headphones_rounded,
      title: 'Sesli özet',
      child: Row(
        children: [
          Expanded(
            child: Text(
              topic.hasNarration
                  ? 'Dersin özetini dinle. Konuyu ekrandan takip ederken sesli özetle hızlı tekrar yapabilirsin.'
                  : 'Bu dersin sesli özeti hazırlanıyor.',
            ),
          ),
          if (topic.hasNarration) ...[
            const SizedBox(width: 10),
            _MetaChip(
              text: premium
                  ? 'Premium • sınırsız'
                  : '${topic.audioCreditCost} kredi / dinleme',
            ),
          ],
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(
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

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.example});
  final StudyExample example;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
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


class _ContentEmptyState extends StatelessWidget {
  const _ContentEmptyState({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 58, height: 58, decoration: BoxDecoration(color: colors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(18)), child: Icon(Icons.auto_stories_outlined, color: colors.primary, size: 29)),
      const SizedBox(height: 14),
      Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
    ])));
  }
}

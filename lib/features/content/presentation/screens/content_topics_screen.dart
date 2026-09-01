import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../domain/content_models.dart';
import '../providers/content_providers.dart';

class ContentTopicsScreen extends ConsumerWidget {
  const ContentTopicsScreen({super.key, required this.subjectId, required this.unitId, this.unitName});
  final String subjectId; final String unitId; final String? unitName;
  @override Widget build(BuildContext context, WidgetRef ref) {
    final args = TopicListArgs(subjectId: subjectId, unitId: unitId); final topics = ref.watch(topicsProvider(args));
    return Scaffold(appBar: AppBar(title: Text(unitName ?? 'Konular')), body: AsyncStateView<List<StudyTopic>>(
      value: topics, isEmpty: (items) => items.isEmpty, empty: const _ContentEmptyState(title: 'Bu ünitede henüz konu yok', message: 'İçerik hazır olduğunda konular burada listelenecek.'), onRetry: () => ref.invalidate(topicsProvider(args)),
      data: (items) => ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 34), children: [
        _Header(name: unitName ?? 'Ünite', count: items.length), const SizedBox(height: 16),
        ...items.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 11), child: _TopicCard(topic: e.value, index: e.key, subjectId: subjectId, unitId: unitId))),
      ]),
    ));
  }
}
class _Header extends StatelessWidget { const _Header({required this.name, required this.count}); final String name; final int count; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4A1F2C), Color(0xFF1F4A3D)]), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x171685C8), blurRadius: 18, offset: Offset(0, 7))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.topic_rounded, color: Colors.white, size: 28), const SizedBox(height: 12), Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)), const SizedBox(height: 4), Text('$count konu • bir konu seçerek çalışmaya başla', style: const TextStyle(color: Color(0xE8FFFFFF))) ])); }
class _TopicCard extends StatelessWidget { const _TopicCard({required this.topic, required this.index, required this.subjectId, required this.unitId}); final StudyTopic topic; final int index; final String subjectId, unitId; @override Widget build(BuildContext context) { final color = topic.isPublished ? const Color(0xFF1F4A3D) : const Color(0xFF4A1F2C); return Material(color: Colors.white, borderRadius: BorderRadius.circular(19), child: InkWell(borderRadius: BorderRadius.circular(19), onTap: () => context.push(AppRoutes.contentTopicDetailPath(subjectId, unitId, topic.id)), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(borderRadius: BorderRadius.circular(19), border: Border.all(color: color.withValues(alpha: .25), width: 1.7), boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 5))]), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFF2E6DC), borderRadius: BorderRadius.circular(13)), child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF4A1F2C), fontWeight: FontWeight.w900))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(topic.title, style: const TextStyle(fontWeight: FontWeight.w900))), const SizedBox(width: 8), _Status(published: topic.isPublished)]), const SizedBox(height: 7), if (topic.examScopes.isNotEmpty) Wrap(spacing: 6, runSpacing: 5, children: topic.examScopes.map((s) => _Scope(text: s)).toList()), if (topic.examScopes.isNotEmpty) const SizedBox(height: 7), Text(topic.isPublished ? '${topic.estimatedReadMinutes} dk okuma • ${topic.shortDescription}' : topic.shortDescription, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35, fontSize: 12))])), const SizedBox(width: 6), const Padding(padding: EdgeInsets.only(top: 10), child: Icon(Icons.chevron_right_rounded))])))); }}
class _Status extends StatelessWidget { const _Status({required this.published}); final bool published; @override Widget build(BuildContext context) { final c = published ? const Color(0xFF1F4A3D) : const Color(0xFF4A1F2C); return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c.withValues(alpha: .10), borderRadius: BorderRadius.circular(999)), child: Text(published ? 'Hazır' : 'Hazırlanıyor', style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 10))); }}
class _Scope extends StatelessWidget { const _Scope({required this.text}); final String text; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE7D7CC), borderRadius: BorderRadius.circular(999)), child: Text(text, style: const TextStyle(color: Color(0xFF1F4A3D), fontWeight: FontWeight.w800, fontSize: 10))); }


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

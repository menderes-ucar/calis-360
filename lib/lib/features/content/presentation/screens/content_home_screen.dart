import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../domain/content_models.dart';
import '../providers/content_providers.dart';

class ContentHomeScreen extends ConsumerWidget {
  const ContentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dersler')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(subjectsProvider.future),
        child: AsyncStateView<List<StudySubject>>(
          value: subjects,
          isEmpty: (items) => items.isEmpty,
          empty: const _EmptyContent(),
          onRetry: () => ref.invalidate(subjectsProvider),
          data: (items) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 34),
            children: [
              const _HeroCard(),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: Text('Derslerini seç', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                _CountBadge(text: '${items.length} ders'),
              ]),
              const SizedBox(height: 5),
              Text('Dersini seç, tüm konu başlıklarını tek listede gör ve istediğin konudan çalışmaya başla.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              ...items.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SubjectCard(subject: entry.value, index: entry.key),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(21),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(colors: [Color(0xFF4A1F2C), Color(0xFF1F4A3D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      boxShadow: const [BoxShadow(color: Color(0x221685C8), blurRadius: 22, offset: Offset(0, 9))],
    ),
    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DecoratedBox(decoration: BoxDecoration(color: Color(0x2AFFFFFF), borderRadius: BorderRadius.all(Radius.circular(14))), child: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.auto_stories_rounded, color: Colors.white, size: 30))),
      SizedBox(height: 18),
      Text('Dersini seç, doğrudan konuya geç', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
      SizedBox(height: 7),
      Text('Aradaki ünite ekranıyla uğraşmadan dersin tüm konularını tek ekranda görüntüle.', style: TextStyle(color: Colors.white, height: 1.45, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.index});
  final StudySubject subject; final int index;
  static const _accents = [Color(0xFF4A1F2C), Color(0xFF1F4A3D), Color(0xFF1F4A3D), Color(0xFF4A1F2C)];
  @override
  Widget build(BuildContext context) {
    final color = _accents[index % _accents.length];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(AppRoutes.contentUnitsPath(subject.id), extra: subject.name),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: .28), width: 1.7), boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 16, offset: Offset(0, 5))]),
          child: Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(16)), child: Icon(_iconFor(subject.iconKey), color: color, size: 26)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subject.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${subject.examGroup} • konu anlatımları', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ])),
            Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: .09), shape: BoxShape.circle), child: Icon(Icons.arrow_forward_rounded, color: color, size: 19)),
          ]),
        ),
      ),
    );
  }
  IconData _iconFor(String key) => switch (key) { 'calculate' => Icons.calculate_rounded, 'science' => Icons.science_rounded, 'language' => Icons.menu_book_rounded, _ => Icons.school_rounded };
}

class _CountBadge extends StatelessWidget { const _CountBadge({required this.text}); final String text; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFF2E6DC), borderRadius: BorderRadius.circular(999)), child: Text(text, style: const TextStyle(color: Color(0xFF4A1F2C), fontWeight: FontWeight.w800, fontSize: 12))); }
class _EmptyContent extends StatelessWidget { const _EmptyContent(); @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: const [SizedBox(height: 100), Icon(Icons.auto_stories_outlined, size: 52), SizedBox(height: 16), Text('Henüz içerik bulunmuyor.', textAlign: TextAlign.center)]); }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../domain/content_models.dart';
import '../providers/content_providers.dart';

class ContentUnitsScreen extends ConsumerWidget {
  const ContentUnitsScreen({super.key, required this.subjectId, this.subjectName});
  final String subjectId; final String? subjectName;
  @override Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider(subjectId));
    return Scaffold(appBar: AppBar(title: Text(subjectName ?? 'Üniteler')), body: AsyncStateView<List<StudyUnit>>(
      value: units, isEmpty: (items) => items.isEmpty, empty: const _ContentEmptyState(title: 'Bu derste henüz ünite yok', message: 'İçerik hazır olduğunda üniteler burada listelenecek.'), onRetry: () => ref.invalidate(unitsProvider(subjectId)),
      data: (items) => ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 34), children: [
        _Header(subjectName: subjectName ?? 'Ders', count: items.length), const SizedBox(height: 18),
        ...items.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 11), child: _UnitCard(unit: e.value, index: e.key, subjectId: subjectId))),
      ]),
    ));
  }
}
class _Header extends StatelessWidget { const _Header({required this.subjectName, required this.count}); final String subjectName; final int count; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFF2E6DC), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF4A1F2C).withValues(alpha: .26), width: 1.7)), child: Row(children: [const Icon(Icons.layers_rounded, color: Color(0xFF4A1F2C), size: 28), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(subjectName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 3), Text('$count ünite • bir ünite seçerek devam et', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))]))])); }
class _UnitCard extends StatelessWidget { const _UnitCard({required this.unit, required this.index, required this.subjectId}); final StudyUnit unit; final int index; final String subjectId; @override Widget build(BuildContext context) { const color = Color(0xFF1F4A3D); return Material(color: Colors.white, borderRadius: BorderRadius.circular(19), child: InkWell(borderRadius: BorderRadius.circular(19), onTap: () => context.push(AppRoutes.contentTopicsPath(subjectId, unit.id), extra: unit.name), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFFD6C5BB), width: 1.7), boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 5))]), child: Row(children: [Container(width: 45, height: 45, alignment: Alignment.center, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)), child: Text('${index + 1}', style: const TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 17))), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(unit.name, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(unit.topicCount > 0 ? '${unit.topicCount} konu' : 'Konuları görüntüle', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))])), const Icon(Icons.chevron_right_rounded, color: color)])))); }}


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

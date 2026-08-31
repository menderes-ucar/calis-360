import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/data_error_mapper.dart';
import '../../../../core/widgets/section_hero_card.dart';
import '../../../../models/dersProgrami.dart';
import '../../../study_data/presentation/providers/study_data_providers.dart';
import '../../data/study_planner_repository.dart';
import '../../domain/study_plan_models.dart';
import '../providers/study_planner_providers.dart';

class AiStudyPlannerScreen extends ConsumerStatefulWidget {
  const AiStudyPlannerScreen({super.key, this.initialWeekNumber = 1});

  final int initialWeekNumber;

  @override
  ConsumerState<AiStudyPlannerScreen> createState() =>
      _AiStudyPlannerScreenState();
}

class _AiStudyPlannerScreenState extends ConsumerState<AiStudyPlannerScreen> {
  static const _days = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  String _examScope = 'TYT + AYT';
  String _field = 'Sayısal';
  int _dailyHours = 4;
  int _studyDays = 6;
  String? _offDay = 'Pazar';
  String _intensity = 'Dengeli';
  late int _targetWeek;
  StudyPlanMode _mode = StudyPlanMode.aiTopics;
  final Set<String> _selectedSubjects = <String>{};
  final Set<String> _weakSubjects = <String>{};
  final Map<String, TextEditingController> _topicControllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _targetWeek = widget.initialWeekNumber.clamp(1, 52);
  }

  @override
  void dispose() {
    for (final controller in _topicControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _needsField => _examScope != 'TYT';

  List<String> get _subjectPool {
    if (_examScope == 'TYT') {
      return const [
        'Türkçe',
        'Matematik',
        'Geometri',
        'Fizik',
        'Kimya',
        'Biyoloji',
        'Tarih',
        'Coğrafya',
        'Felsefe',
        'Din',
      ];
    }
    switch (_field) {
      case 'Eşit Ağırlık':
        return const [
          'Matematik',
          'Geometri',
          'Türkçe',
          'Edebiyat',
          'Tarih',
          'Coğrafya',
        ];
      case 'Sözel':
        return const [
          'Türkçe',
          'Edebiyat',
          'Tarih',
          'Coğrafya',
          'Felsefe',
          'Din',
        ];
      default:
        return const [
          'Matematik',
          'Geometri',
          'Fizik',
          'Kimya',
          'Biyoloji',
          'Türkçe',
        ];
    }
  }

  void _syncSubjects() {
    _selectedSubjects.removeWhere((item) => !_subjectPool.contains(item));
    _weakSubjects.removeWhere((item) => !_subjectPool.contains(item));
  }

  TextEditingController _topicController(String subject) {
    return _topicControllers.putIfAbsent(subject, TextEditingController.new);
  }

  Map<String, List<String>> _selectedTopics() {
    final result = <String, List<String>>{};
    for (final subject in _selectedSubjects) {
      final values = _topicController(subject).text
          .split(RegExp(r'[,;\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .take(20)
          .toList(growable: false);
      if (values.isNotEmpty) result[subject] = values;
    }
    return result;
  }

  Future<void> _generate() async {
    if (_selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir ders seçmelisin.')),
      );
      return;
    }

    final topics = _selectedTopics();
    if (_mode == StudyPlanMode.manualTopics &&
        _selectedSubjects.any(
          (subject) => (topics[subject] ?? const []).isEmpty,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Konu bazlı planda seçtiğin her ders için en az bir konu yazmalısın.',
          ),
        ),
      );
      return;
    }

    final request = StudyPlanRequest(
      examScope: _examScope,
      field: _needsField ? _field : 'TYT',
      dailyHours: _dailyHours,
      studyDays: _studyDays,
      offDay: _studyDays == 7 ? null : _offDay,
      intensity: _intensity,
      weakSubjects: _weakSubjects.toList(growable: false),
      mode: _mode,
      selectedSubjects: _selectedSubjects.toList(growable: false),
      selectedTopics: topics,
      targetWeek: _targetWeek,
    );

    final plan = await ref
        .read(studyPlannerControllerProvider.notifier)
        .generate(request);
    if (!mounted || plan != null) return;

    final state = ref.read(studyPlannerControllerProvider);
    final message = state.hasError
        ? DataErrorMapper.message(state.error!)
        : 'AI programı oluşturulamadı.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmExistingWeek() async {
    final exists = await ref
        .read(dersProgramiRepositoryProvider)
        .hasProgramInWeek(_targetWeek);
    if (!exists || !mounted) return true;

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('$_targetWeek. haftada program var'),
            content: const Text(
              'Bu haftadaki mevcut çalışmalar silinmeyecek. AI programını mevcut programa eklemek istiyor musun?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Mevcut Programa Ekle'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _savePlan(GeneratedStudyPlan plan) async {
    if (!await _confirmExistingWeek()) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(dersProgramiRepositoryProvider);
      final items = plan.sessions
          .map((session) {
            return DersProgram(
              dersProgramId: repo.createId(),
              dersProgramSinavTur: session.examType.isEmpty
                  ? _examScope
                  : session.examType,
              dersProgramDersAd: session.subject,
              dersProgramKonuAd: session.topic,
              dersProgramGun: session.day,
              dersProgramSaat: session.startHour,
              durationMinutes: session.durationMinutes,
              source: 'ai',
              weekNumber: _targetWeek,
            );
          })
          .toList(growable: false);

      await repo.addAiGeneratedWeek(items);
      if (!mounted) return;

      final goToProgram =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              icon: const Icon(Icons.check_circle_rounded, size: 42),
              title: const Text('Programınız eklendi'),
              content: Text(
                '$_targetWeek. hafta çalışma programınız Program bölümüne başarıyla eklendi.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Burada Kal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Programı Gör'),
                ),
              ],
            ),
          ) ??
          false;

      if (!mounted) return;
      if (goToProgram) {
        Navigator.of(context).pop(_targetWeek);
      } else {
        ref.read(studyPlannerControllerProvider.notifier).clear();
      }
    } catch (error) {
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
    final state = ref.watch(studyPlannerControllerProvider);
    final plan = state.asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Haftalık Program')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const SectionHeroCard(
            icon: Icons.auto_awesome_rounded,
            title: 'Programını AI hazırlasın',
            subtitle:
                'Ders bazlı, kendi konularınla veya AI konu seçimiyle tek haftalık bir taslak oluştur. Sen kabul etmeden Program bölümüne eklenmez.',
          ),
          const SizedBox(height: 16),
          _QuestionCard(
            title: '1. Nasıl bir program istiyorsun?',
            child: Column(
              children: [
                _ModeTile(
                  title: 'AI konuları seçsin',
                  subtitle:
                      'Dersleri sen seç, o hafta çalışılacak konuları AI belirlesin.',
                  selected: _mode == StudyPlanMode.aiTopics,
                  onTap: () => setState(() => _mode = StudyPlanMode.aiTopics),
                ),
                _ModeTile(
                  title: 'Konuları ben seçeyim',
                  subtitle:
                      'Dersleri ve çalışmak istediğin konuları kendin belirle.',
                  selected: _mode == StudyPlanMode.manualTopics,
                  onTap: () =>
                      setState(() => _mode = StudyPlanMode.manualTopics),
                ),
                _ModeTile(
                  title: 'Sadece ders programı',
                  subtitle:
                      'Konu kullanmadan yalnızca ders ve süre bazlı program oluştur.',
                  selected: _mode == StudyPlanMode.subjectsOnly,
                  onTap: () =>
                      setState(() => _mode = StudyPlanMode.subjectsOnly),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _QuestionCard(
            title: '2. Bu program hangi hafta için?',
            subtitle: 'Kabul ettiğinde seçtiğin haftaya kaydedilir.',
            child: DropdownButtonFormField<int>(
              value: _targetWeek,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.date_range_rounded),
                labelText: 'Program haftası',
              ),
              items: List.generate(
                52,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1}. Hafta'),
                ),
              ),
              onChanged: plan != null
                  ? null
                  : (value) {
                      if (value != null) setState(() => _targetWeek = value);
                    },
            ),
          ),
          const SizedBox(height: 12),
          _QuestionCard(
            title: '3. Hangi sınav için?',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['TYT', 'AYT', 'TYT + AYT']
                  .map(
                    (item) => ChoiceChip(
                      label: Text(item),
                      selected: _examScope == item,
                      onSelected: plan != null
                          ? null
                          : (_) => setState(() {
                              _examScope = item;
                              _syncSubjects();
                            }),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_needsField) ...[
            const SizedBox(height: 12),
            _QuestionCard(
              title: '4. Alanın nedir?',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Sayısal', 'Eşit Ağırlık', 'Sözel']
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item),
                        selected: _field == item,
                        onSelected: plan != null
                            ? null
                            : (_) => setState(() {
                                _field = item;
                                _syncSubjects();
                              }),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _QuestionCard(
            title: '5. Hangi dersleri çalışmak istiyorsun?',
            subtitle: 'En az bir ders seç.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _subjectPool
                  .map(
                    (item) => FilterChip(
                      label: Text(item),
                      selected: _selectedSubjects.contains(item),
                      onSelected: plan != null
                          ? null
                          : (selected) => setState(() {
                              if (selected) {
                                _selectedSubjects.add(item);
                              } else {
                                _selectedSubjects.remove(item);
                                _weakSubjects.remove(item);
                              }
                            }),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_mode == StudyPlanMode.manualTopics &&
              _selectedSubjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            _QuestionCard(
              title: '6. Konularını seç',
              subtitle: 'Her ders için konuları virgülle ayırarak yaz.',
              child: Column(
                children: _selectedSubjects
                    .map(
                      (subject) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: _topicController(subject),
                          enabled: plan == null,
                          decoration: InputDecoration(
                            labelText: '$subject konuları',
                            hintText: 'Örn. Problemler, Fonksiyonlar',
                            prefixIcon: const Icon(Icons.topic_outlined),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _QuestionCard(
            title: 'Günde kaç saat çalışabilirsin?',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [2, 3, 4, 5, 6, 7, 8]
                  .map(
                    (item) => ChoiceChip(
                      label: Text('$item saat'),
                      selected: _dailyHours == item,
                      onSelected: plan != null
                          ? null
                          : (_) => setState(() => _dailyHours = item),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _QuestionCard(
            title: 'Haftada kaç gün çalışacaksın?',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [5, 6, 7]
                  .map(
                    (item) => ChoiceChip(
                      label: Text('$item gün'),
                      selected: _studyDays == item,
                      onSelected: plan != null
                          ? null
                          : (_) => setState(() {
                              _studyDays = item;
                              if (item == 7) _offDay = null;
                              if (item < 7 && _offDay == null)
                                _offDay = 'Pazar';
                            }),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_studyDays < 7) ...[
            const SizedBox(height: 12),
            _QuestionCard(
              title: 'Dinlenme günün hangisi?',
              child: DropdownButtonFormField<String>(
                value: _offDay,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.weekend_outlined),
                  labelText: 'Dinlenme günü',
                ),
                items: _days
                    .map(
                      (day) => DropdownMenuItem(value: day, child: Text(day)),
                    )
                    .toList(),
                onChanged: plan != null
                    ? null
                    : (value) => setState(() => _offDay = value),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _QuestionCard(
            title: 'Program yoğunluğu',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Rahat', 'Dengeli', 'Yoğun']
                  .map(
                    (item) => ChoiceChip(
                      label: Text(item),
                      selected: _intensity == item,
                      onSelected: plan != null
                          ? null
                          : (_) => setState(() => _intensity = item),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _QuestionCard(
            title: 'Öncelik vermek istediğin dersler',
            subtitle: 'İsteğe bağlı. AI seçtiklerine daha fazla süre ayırır.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedSubjects
                  .map(
                    (item) => FilterChip(
                      label: Text(item),
                      selected: _weakSubjects.contains(item),
                      onSelected: plan != null
                          ? null
                          : (selected) => setState(() {
                              if (selected) {
                                _weakSubjects.add(item);
                              } else {
                                _weakSubjects.remove(item);
                              }
                            }),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.toll_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI taslağı ${StudyPlannerRepository.programCreditCost} kredi kullanır. Taslak ancak sen kabul edersen Program bölümüne kaydedilir.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (plan == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.isLoading ? null : _generate,
                icon: state.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  state.isLoading
                      ? 'Program hazırlanıyor...'
                      : 'AI ile Program Oluştur • ${StudyPlannerRepository.programCreditCost} kredi',
                ),
              ),
            ),
          if (plan != null) ...[
            const SizedBox(height: 20),
            _PlanPreview(plan: plan, weekNumber: _targetWeek),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => ref
                              .read(studyPlannerControllerProvider.notifier)
                              .clear(),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Taslağı Reddet'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _savePlan(plan),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_saving ? 'Ekleniyor...' : 'Programı Kabul Et'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer.withValues(alpha: .45)
              : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 1.7 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: (_) => onTap(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PlanPreview extends StatelessWidget {
  const _PlanPreview({required this.plan, required this.weekNumber});

  final GeneratedStudyPlan plan;
  final int weekNumber;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<GeneratedStudySession>>{};
    for (final session in plan.sessions) {
      grouped.putIfAbsent(session.day, () => []).add(session);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$weekNumber. Hafta Taslağı',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(plan.title),
            if (plan.summary.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(plan.summary),
            ],
            const SizedBox(height: 12),
            for (final entry in grouped.entries) ...[
              Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              for (final session in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    '${session.startHour.toString().padLeft(2, '0')}:00 • '
                    '${session.subject}'
                    '${session.topic.isEmpty ? '' : ' — ${session.topic}'} '
                    '(${session.durationMinutes} dk)',
                  ),
                ),
              const SizedBox(height: 6),
            ],
            const Divider(height: 22),
            Text(
              '${plan.creditCost} kredi kullanıldı • Kalan: ${plan.remainingCredits}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

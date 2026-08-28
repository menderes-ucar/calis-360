import 'dart:async';

import 'package:flutter/material.dart';

import 'home_card_style.dart';

class CountdownWidget extends StatefulWidget {
  const CountdownWidget({super.key});

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget> {
  // Mevcut uygulama verisindeki son sınav tarihi. Tarih geçtiğinde artık
  // kullanıcıya yanıltıcı biçimde "0 gün" göstermiyoruz.
  final DateTime examDate = DateTime(2026, 6, 15, 10);
  Duration remainingTime = Duration.zero;
  Timer? timer;

  bool get _examFinished => !examDate.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    if (!_examFinished) {
      timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _updateRemainingTime(),
      );
    }
  }

  void _updateRemainingTime() {
    if (!mounted) return;
    final difference = examDate.difference(DateTime.now());
    setState(() {
      remainingTime = difference.isNegative ? Duration.zero : difference;
    });
    if (difference.isNegative) timer?.cancel();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_examFinished) {
      return _FinishedExamCard(examYear: examDate.year);
    }

    final days = remainingTime.inDays;
    final hours = remainingTime.inHours % 24;
    final minutes = remainingTime.inMinutes % 60;

    return Card(
      elevation: 4,
      shadowColor: const Color(0xFF172033).withValues(alpha: 0.16),
      shape: HomeCardStyle.shape,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YKS ${examDate.year}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sınava kalan süre',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );

            final timerRow = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TimeValue(value: '$days', label: 'gün'),
                const SizedBox(width: 16),
                _TimeValue(value: '$hours', label: 'saat'),
                const SizedBox(width: 16),
                _TimeValue(value: '$minutes', label: 'dk'),
              ],
            );

            if (constraints.maxWidth < 340) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 16),
                  Align(alignment: Alignment.centerRight, child: timerRow),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: title),
                timerRow,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FinishedExamCard extends StatelessWidget {
  const _FinishedExamCard({required this.examYear});

  final int examYear;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: const Color(0xFF172033).withValues(alpha: 0.16),
      shape: HomeCardStyle.shape,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: Color(0xFF1685C8),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YKS $examYear tamamlandı',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Yeni sınav tarihi belirlendiğinde geri sayım burada başlayacak.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeValue extends StatelessWidget {
  const _TimeValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

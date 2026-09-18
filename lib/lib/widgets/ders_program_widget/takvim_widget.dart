import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/sinav_takvimi.dart';

class SinavTakvimiWidget extends StatefulWidget {
  final List<SinavTakvimi> sinavlar;

  const SinavTakvimiWidget({super.key, required this.sinavlar});

  @override
  State<SinavTakvimiWidget> createState() => _SinavTakvimiWidgetState();
}

class _SinavTakvimiWidgetState extends State<SinavTakvimiWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TableCalendar(
      focusedDay: _focusedDay,
      firstDay: DateTime(2000),
      lastDay: DateTime(2100),
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      calendarFormat: CalendarFormat.month,
      rowHeight: 48,
      daysOfWeekHeight: 30,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: false,
        leftChevronPadding: const EdgeInsets.all(8),
        rightChevronPadding: const EdgeInsets.all(8),
        titleTextStyle: theme.textTheme.titleMedium!.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: theme.textTheme.labelSmall!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        weekendStyle: theme.textTheme.labelSmall!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        defaultTextStyle: const TextStyle(fontWeight: FontWeight.w600),
        weekendTextStyle: const TextStyle(fontWeight: FontWeight.w600),
        selectedDecoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w900,
        ),
        todayDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          final bugunSinav = widget.sinavlar
              .where((s) => isSameDay(s.sinavZamani, day))
              .toList(growable: false);
          if (bugunSinav.isEmpty) return null;

          final hasTyt = bugunSinav.any((s) => s.sinavTur == 'TYT');
          return Positioned(
            bottom: 4,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: hasTyt
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
    );
  }
}

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
      rowHeight: 50,
      daysOfWeekHeight: 28,
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          final bugunSinav = widget.sinavlar.where((s) => isSameDay(s.sinavZamani, day)).toList();
          if (bugunSinav.isEmpty) return null;

          Color renk = Colors.black;
          if (bugunSinav.any((s) => s.sinavTur == "TYT")) renk = Colors.blue;
          else if (bugunSinav.any((s) => s.sinavTur == "AYT")) renk = Colors.red;

          return Container(
            margin: const EdgeInsets.only(top: 30),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: renk,
              shape: BoxShape.circle,
            ),
          );
        },
      ),
    );
  }
}

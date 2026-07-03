import 'package:flutter/material.dart';
import 'dart:async';

class CountdownWidget extends StatefulWidget {
  const CountdownWidget({super.key});

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget> {
  Duration remainingTime = Duration();
  Timer? timer;

  // 🎯 YKS tarihi
  DateTime examDate = DateTime(2026, 6, 15, 10, 0, 0);

  @override
  void initState() {
    super.initState();
    updateRemainingTime();
    timer = Timer.periodic(Duration(seconds: 1), (_) => updateRemainingTime());
  }

  void updateRemainingTime() {
    final now = DateTime.now();
    setState(() {
      remainingTime = examDate.difference(now);
      if (remainingTime.isNegative) {
        timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = remainingTime.inDays;
    final hours = remainingTime.inHours % 24;
    final minutes = remainingTime.inMinutes % 60;
    final seconds = remainingTime.inSeconds % 60;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            children: [
              _timeText("$days", "Gün"),
              _timeText("$hours", "Saat"),
              _timeText("$minutes", "Dakika"),
              _timeText("$seconds", "Saniye"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeText(String time, String label) {
    return Column(
      children: [
        Text(
          time,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

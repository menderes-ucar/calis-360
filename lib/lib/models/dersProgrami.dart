// ignore_for_file: file_names
import 'package:cloud_firestore/cloud_firestore.dart';

class DersProgram {
  final String dersProgramId;
  final String dersProgramSinavTur;
  final String dersProgramDersAd;
  final String dersProgramKonuAd;
  final String dersProgramGun;
  final int dersProgramSaat;
  final bool tamamlandi;
  final int durationMinutes;
  final String source;
  final int weekNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DersProgram({
    required this.dersProgramId,
    required this.dersProgramSinavTur,
    required this.dersProgramDersAd,
    required this.dersProgramKonuAd,
    required this.dersProgramGun,
    required this.dersProgramSaat,
    this.tamamlandi = false,
    this.durationMinutes = 60,
    this.source = 'manual',
    this.weekNumber = 1,
    this.createdAt,
    this.updatedAt,
  });

  factory DersProgram.fromjson(Map<String, dynamic> json, String key) {
    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    int readInt(dynamic value, {required int fallback}) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    String readDay(dynamic value) {
      final raw = (value ?? '').toString().trim();
      final normalized = raw
          .toLowerCase()
          .replaceAll('ı', 'i')
          .replaceAll('ş', 's')
          .replaceAll('ç', 'c')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ö', 'o')
          .replaceAll('.', '')
          .trim();

      switch (normalized) {
        case 'pazartesi':
        case 'pzt':
        case 'monday':
        case 'mon':
          return 'Pazartesi';
        case 'sali':
        case 'sal':
        case 'tuesday':
        case 'tue':
        case 'tues':
          return 'Salı';
        case 'carsamba':
        case 'car':
        case 'wednesday':
        case 'wed':
          return 'Çarşamba';
        case 'persembe':
        case 'per':
        case 'thursday':
        case 'thu':
        case 'thur':
        case 'thurs':
          return 'Perşembe';
        case 'cuma':
        case 'cum':
        case 'friday':
        case 'fri':
          return 'Cuma';
        case 'cumartesi':
        case 'cmt':
        case 'saturday':
        case 'sat':
          return 'Cumartesi';
        case 'pazar':
        case 'paz':
        case 'sunday':
        case 'sun':
          return 'Pazar';
        default:
          return raw;
      }
    }

    final rawSaat = json['dersProgramSaat'];
    final rawDuration = json['durationMinutes'];
    final rawWeekNumber = json['weekNumber'];

    final parsedWeekNumber = readInt(rawWeekNumber, fallback: 1);

    return DersProgram(
      dersProgramId: key,
      dersProgramSinavTur: (json['dersProgramSinavTur'] ?? '').toString(),
      dersProgramDersAd: (json['dersProgramDersAd'] ?? '').toString(),
      dersProgramKonuAd: (json['dersProgramKonuAd'] ?? '').toString(),
      dersProgramGun: readDay(json['dersProgramGun']),
      dersProgramSaat: readInt(rawSaat, fallback: 0).clamp(0, 23),
      tamamlandi: json['tamamlandi'] == true,
      durationMinutes: readInt(rawDuration, fallback: 60) <= 0
          ? 60
          : readInt(rawDuration, fallback: 60),
      source: (json['source'] ?? 'manual').toString().trim().isEmpty
          ? 'manual'
          : (json['source'] ?? 'manual').toString().trim(),
      weekNumber: parsedWeekNumber <= 0 ? 1 : parsedWeekNumber,
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dersProgramSinavTur': dersProgramSinavTur,
      'dersProgramDersAd': dersProgramDersAd,
      'dersProgramKonuAd': dersProgramKonuAd,
      'dersProgramGun': dersProgramGun,
      'dersProgramSaat': dersProgramSaat,
      'tamamlandi': tamamlandi,
      'durationMinutes': durationMinutes,
      'source': source,
      'weekNumber': weekNumber,
    };
  }
}

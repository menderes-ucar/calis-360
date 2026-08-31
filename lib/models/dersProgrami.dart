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
    DateTime? readDate(dynamic value) =>
        value is Timestamp ? value.toDate() : null;

    return DersProgram(
      dersProgramId: key,
      dersProgramSinavTur: (json['dersProgramSinavTur'] ?? '').toString(),
      dersProgramDersAd: (json['dersProgramDersAd'] ?? '').toString(),
      dersProgramKonuAd: (json['dersProgramKonuAd'] ?? '').toString(),
      dersProgramGun: (json['dersProgramGun'] ?? '').toString(),
      dersProgramSaat: (json['dersProgramSaat'] ?? 0) is num
          ? (json['dersProgramSaat'] as num).toInt()
          : int.tryParse((json['dersProgramSaat'] ?? '0').toString()) ?? 0,
      tamamlandi: json['tamamlandi'] == true,
      durationMinutes: (json['durationMinutes'] ?? 60) is num
          ? (json['durationMinutes'] as num).toInt()
          : int.tryParse((json['durationMinutes'] ?? '60').toString()) ?? 60,
      source: (json['source'] ?? 'manual').toString(),
      weekNumber: (json['weekNumber'] ?? 1) is num
          ? (json['weekNumber'] as num).toInt()
          : int.tryParse((json['weekNumber'] ?? '1').toString()) ?? 1,
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

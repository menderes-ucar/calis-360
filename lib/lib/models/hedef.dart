import 'package:cloud_firestore/cloud_firestore.dart';

class Hedef {
  final String hedefId;
  final String hedefAd;
  final String hedefNote;
  final DateTime hedefTarihi;
  final String hedefZamani;
  final bool tamamlandi;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Hedef({
    required this.hedefId,
    required this.hedefAd,
    required this.hedefNote,
    required this.hedefTarihi,
    required this.hedefZamani,
    this.tamamlandi = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Hedef.fromJson(Map<dynamic, dynamic> json, String key) {
    DateTime? readDate(dynamic value) =>
        value is Timestamp ? value.toDate() : null;
    final hedefTarihi = readDate(json['hedefTarihi']) ?? DateTime.now();

    return Hedef(
      hedefId: key,
      hedefAd: (json['hedefAd'] ?? '').toString(),
      hedefNote: (json['hedefNote'] ?? '').toString(),
      hedefTarihi: hedefTarihi,
      tamamlandi: json['tamamlandi'] == true,
      hedefZamani: (json['hedefZamani'] ?? 'Günlük Hedef').toString(),
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'hedefAd': hedefAd,
    'hedefNote': hedefNote,
    'hedefTarihi': hedefTarihi,
    'tamamlandi': tamamlandi,
    'hedefZamani': hedefZamani,
  };
}

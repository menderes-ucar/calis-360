import 'package:cloud_firestore/cloud_firestore.dart';

class Hedef {
  final String hedefId;
  final String hedefAd;
  final String hedefNote;
  final DateTime hedefTarihi;
  final String hedefZamani;
  final bool tamamlandi;

  Hedef({
    required this.hedefId,
    required this.hedefAd,
    required this.hedefNote,
    required this.hedefTarihi,
    required this.hedefZamani,
    this.tamamlandi = false,
  });
  factory Hedef.fromJson(Map<dynamic,dynamic>json,String key){
    return Hedef(
        hedefId: key,
        hedefAd: json["hedefAd"] as String,
        hedefNote: json["hedefNote"] as String,
        hedefTarihi: (json["hedefTarihi"] as Timestamp).toDate(),
        tamamlandi: json['tamamlandi'] ?? false,
        hedefZamani: json['hedefZamani'] ?? "Günlük Hedef",

    );
  }
  Map<String, dynamic> toJson() {
    return {
      'hedefAd': hedefAd,
      'hedefNote': hedefNote,
      'hedefTarihi': hedefTarihi,
      'tamamlandi': tamamlandi,
      'hedefZamani': hedefZamani,
    };
  }
}

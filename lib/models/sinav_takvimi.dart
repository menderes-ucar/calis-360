import 'package:cloud_firestore/cloud_firestore.dart';

class SinavTakvimi{
  final String sinavId;
  final String sinavTur;
  final DateTime sinavZamani;

  SinavTakvimi ({
   required this.sinavId,
    required this.sinavTur,
    required this.sinavZamani,
});
  factory SinavTakvimi.fromjson(Map<dynamic,dynamic>json,String key){
    return SinavTakvimi(
        sinavId: key,
        sinavTur: json["sinavTur"] as String,
        sinavZamani: (json["sinavZamani"] as Timestamp).toDate(),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      "sinavTur": sinavTur,
      "sinavZamani": sinavZamani,
    };
    }
}
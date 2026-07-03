import 'package:cloud_firestore/cloud_firestore.dart';

class Sinav {
  final String sinavId;
  final String sinavAd;
  final String sinavTuru;  // TYT / AYT
  final String? sinavBrans; // AYT için: Sayısal / Sözel / EA / Dil
  final Map<String, double> netler; // ders: net

  Sinav({
    required this.sinavId,
    required this.sinavAd,
    required this.sinavTuru,
    this.sinavBrans,
    required this.netler,
  });

  factory Sinav.fromJson(Map<dynamic, dynamic> json, String key) {
    return Sinav(
      sinavId: key,
      sinavAd: json["sinavAd"] as String,
      sinavTuru: json["sinavTuru"] as String,
      sinavBrans: json["sinavBrans"] as String?,
      netler: Map<String, double>.from(
        (json["netler"] ?? {}).map(
              (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "sinavAd": sinavAd,
      "sinavTuru": sinavTuru,
      "sinavBrans": sinavBrans,
      "netler": netler,
    };
  }
}

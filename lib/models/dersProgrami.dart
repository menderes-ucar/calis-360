class DersProgram {
  final String dersProgramId;
  final String dersProgramSinavTur;
  final String dersProgramDersAd;
  final String dersProgramKonuAd;
  final String dersProgramGun;
  final int dersProgramSaat;
  final bool tamamlandi;

  DersProgram({
    required this.dersProgramId,
    required this.dersProgramSinavTur,
    required this.dersProgramDersAd,
    required this.dersProgramKonuAd,
    required this.dersProgramGun,
    required this.dersProgramSaat,
    this.tamamlandi = false,
  });

  factory DersProgram.fromjson(Map<String, dynamic> json, String key) {
    return DersProgram(
      dersProgramId: key,
      dersProgramSinavTur: (json["dersProgramSinavTur"] ?? "") as String,
      dersProgramDersAd: (json["dersProgramDersAd"] ?? "") as String,
      dersProgramKonuAd: (json["dersProgramKonuAd"] ?? "") as String,
      dersProgramGun: (json["dersProgramGun"] ?? "") as String,
      dersProgramSaat: (json["dersProgramSaat"] ?? 0).toInt(),
      tamamlandi: (json["tamamlandi"] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "dersProgramSinavTur": dersProgramSinavTur,
      "dersProgramDersAd": dersProgramDersAd,
      "dersProgramKonuAd": dersProgramKonuAd,
      "dersProgramGun": dersProgramGun,
      "dersProgramSaat": dersProgramSaat,
      "tamamlandi": tamamlandi,
    };
  }
}

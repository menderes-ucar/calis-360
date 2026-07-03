class Soru {
  final String soruId;
  final String soruAd;
  final String soruDers;
  final String soruKonu;
  final String soruCevap;

  Soru({
    required this.soruId,
    required this.soruAd,
    required this.soruDers,
    required this.soruKonu,
    required this.soruCevap,
  });

  factory Soru.fromJson(Map<dynamic, dynamic> json, String key) {
    return Soru(
      soruId: key,
      soruAd: json["soruAd"] as String,
      soruDers: json["soruDers"] as String,
      soruKonu: json["soruKonu"] as String,
      soruCevap: json["soruCevap"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "soruAd": soruAd,
      "soruDers": soruDers,
      "soruKonu": soruKonu,
      "soruCevap": soruCevap,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class SinavKonuDetay {
  const SinavKonuDetay({
    required this.dogru,
    required this.yanlis,
    required this.bos,
  });

  final int dogru;
  final int yanlis;
  final int bos;

  int get toplam => dogru + yanlis + bos;
  double? get basariOrani => toplam == 0 ? null : dogru / toplam;

  factory SinavKonuDetay.fromJson(Map<dynamic, dynamic> json) {
    int readInt(dynamic value) => value is num ? value.toInt() : 0;
    return SinavKonuDetay(
      dogru: readInt(json['dogru']),
      yanlis: readInt(json['yanlis']),
      bos: readInt(json['bos']),
    );
  }

  Map<String, dynamic> toJson() => {
    'dogru': dogru,
    'yanlis': yanlis,
    'bos': bos,
  };
}

class SinavDersDetay {
  const SinavDersDetay({
    required this.dogru,
    required this.yanlis,
    required this.bos,
    required this.net,
    this.konular = const <String, SinavKonuDetay>{},
  });

  final int dogru;
  final int yanlis;
  final int bos;
  final double net;
  final Map<String, SinavKonuDetay> konular;

  int get toplam => dogru + yanlis + bos;
  double? get basariOrani => toplam == 0 ? null : dogru / toplam;
  bool get hasQuestionBreakdown => toplam > 0;
  bool get hasTopicBreakdown => konular.isNotEmpty;

  factory SinavDersDetay.fromJson(Map<dynamic, dynamic> json) {
    int readInt(dynamic value) => value is num ? value.toInt() : 0;
    double readDouble(dynamic value) => value is num ? value.toDouble() : 0;

    final konular = <String, SinavKonuDetay>{};
    final rawKonular = json['konular'];
    if (rawKonular is Map) {
      for (final entry in rawKonular.entries) {
        if (entry.value is Map) {
          konular[entry.key.toString()] = SinavKonuDetay.fromJson(
            Map<dynamic, dynamic>.from(entry.value as Map),
          );
        }
      }
    }

    return SinavDersDetay(
      dogru: readInt(json['dogru']),
      yanlis: readInt(json['yanlis']),
      bos: readInt(json['bos']),
      net: readDouble(json['net']),
      konular: konular,
    );
  }

  Map<String, dynamic> toJson() => {
    'dogru': dogru,
    'yanlis': yanlis,
    'bos': bos,
    'net': net,
    'konular': {
      for (final entry in konular.entries) entry.key: entry.value.toJson(),
    },
  };
}

class Sinav {
  final String sinavId;
  final String sinavAd;
  final String sinavTuru;
  final String? sinavBrans;
  final Map<String, double> netler;
  final Map<String, SinavDersDetay> dersDetaylari;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Sinav({
    required this.sinavId,
    required this.sinavAd,
    required this.sinavTuru,
    this.sinavBrans,
    required this.netler,
    this.dersDetaylari = const <String, SinavDersDetay>{},
    this.createdAt,
    this.updatedAt,
  });

  bool get hasDetailedBreakdown => dersDetaylari.values.any(
    (detail) => detail.hasQuestionBreakdown || detail.hasTopicBreakdown,
  );

  factory Sinav.fromJson(Map<dynamic, dynamic> json, String key) {
    DateTime? readDate(dynamic value) =>
        value is Timestamp ? value.toDate() : null;

    final rawNetler = json['netler'];
    final netler = <String, double>{};
    if (rawNetler is Map) {
      for (final entry in rawNetler.entries) {
        final value = entry.value;
        if (value is num) netler[entry.key.toString()] = value.toDouble();
      }
    }

    final dersDetaylari = <String, SinavDersDetay>{};
    final rawDersDetaylari = json['dersDetaylari'];
    if (rawDersDetaylari is Map) {
      for (final entry in rawDersDetaylari.entries) {
        if (entry.value is Map) {
          dersDetaylari[entry.key.toString()] = SinavDersDetay.fromJson(
            Map<dynamic, dynamic>.from(entry.value as Map),
          );
        }
      }
    }

    // Yeni kayıtlarda net, ders detayından da güvenli biçimde geri üretilebilir.
    for (final entry in dersDetaylari.entries) {
      netler.putIfAbsent(entry.key, () => entry.value.net);
    }

    return Sinav(
      sinavId: key,
      sinavAd: (json['sinavAd'] ?? '').toString(),
      sinavTuru: (json['sinavTuru'] ?? '').toString(),
      sinavBrans: json['sinavBrans']?.toString(),
      netler: netler,
      dersDetaylari: dersDetaylari,
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'sinavAd': sinavAd,
    'sinavTuru': sinavTuru,
    'sinavBrans': sinavBrans,
    'netler': netler,
    if (dersDetaylari.isNotEmpty)
      'dersDetaylari': {
        for (final entry in dersDetaylari.entries)
          entry.key: entry.value.toJson(),
      },
  };
}

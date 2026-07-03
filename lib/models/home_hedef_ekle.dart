class HomeHedef {
  final String id;
  final int net;
  final String bolum;
  final String uni;

  HomeHedef({
    required this.id,
    required this.net,
    required this.bolum,
    required this.uni,
  });

  factory HomeHedef.fromJson(Map<String, dynamic> json,String key) {
    return HomeHedef(
      id:json["id"] as String,
      net: json['net'] as int,
      bolum: json['bolum'] as String,
      uni: json['uni'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      'net': net,
      'bolum': bolum,
      'uni': uni,
    };
  }
}

class HomeHedef {
  final String id;
  final int net;
  final String bolum;
  final String uni;

  const HomeHedef({
    required this.id,
    required this.net,
    required this.bolum,
    required this.uni,
  });

  factory HomeHedef.fromJson(Map<String, dynamic> json, String key) {
    return HomeHedef(
      id: (json['id'] ?? key).toString(),
      net: (json['net'] as num?)?.toInt() ?? 0,
      bolum: (json['bolum'] ?? '').toString(),
      uni: (json['uni'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'net': net, 'bolum': bolum, 'uni': uni};
  }
}

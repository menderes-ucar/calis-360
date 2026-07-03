import 'package:flutter/material.dart';
import '../../models/sınav.dart';
import '../../repositories/sinav_repo.dart';

class SinavEkle extends StatefulWidget {
  const SinavEkle({super.key});

  @override
  State<SinavEkle> createState() => _SinavEkleState();
}

final TextEditingController adController = TextEditingController();

String? secilenTur;
String? secilenBrans;

// Derslerin netlerini saklamak için map
final Map<String, TextEditingController> dersNetControllers = {};

class _SinavEkleState extends State<SinavEkle> {
  final List<String> sinavTuru = ["TYT", "AYT"];
  final List<String> aytBrans = ["Sayısal", "Eşit Ağırlık", "Sözel", "Dil"];

  // Ders listeleri
  final List<String> tytDersler = [
    "Türkçe",
    "Tarih",
    "Coğrafya",
    "Felsefe",
    "Din",
    "Matematik",
    "Fizik",
    "Kimya",
    "Biyoloji"
  ];

  final Map<String, List<String>> aytDersler = {
    "Sayısal": ["Matematik", "Fizik", "Kimya", "Biyoloji"],
    "Eşit Ağırlık": ["Türkçe", "Tarih", "Coğrafya", "Matematik"],
    "Sözel": ["Türkçe", "Tarih", "Coğrafya", "Felsefe", "Din"],
    "Dil": ["İngilizce", "Almanca", "Fransızca"]
  };

  @override
  Widget build(BuildContext context) {
    List<String> aktifDersler = [];
    if (secilenTur == "TYT") {
      aktifDersler = tytDersler;
    } else if (secilenTur == "AYT" && secilenBrans != null) {
      aktifDersler = aytDersler[secilenBrans] ?? [];
    }

    for (var ders in aktifDersler) {
      dersNetControllers.putIfAbsent(ders, () => TextEditingController());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Sınav Ekle"),
        backgroundColor: Color(0xFFE4080A),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE4080A),
              Color(0xFFFE9900),
              Color(0xFFFFDE59),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: adController,
                  decoration: InputDecoration(
                    labelText: "Sınavın adını Yaz",
                    labelStyle: TextStyle(color: Colors.black),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: DropdownButton<String>(
                  hint: Text("Sınav türü Seç"),
                  value: secilenTur,
                  isExpanded: true,
                  items: sinavTuru.map((tur) {
                    return DropdownMenuItem(
                      value: tur,
                      child: Text(tur),
                    );
                  }).toList(),
                  onChanged: (yeniDeger) {
                    setState(() {
                      secilenTur = yeniDeger;
                      secilenBrans = null;
                    });
                  },
                ),
              ),
              if (secilenTur == "AYT")
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: DropdownButton<String>(
                    hint: Text("Branş Seç"),
                    value: secilenBrans,
                    isExpanded: true,
                    items: aytBrans.map((brans) {
                      return DropdownMenuItem(
                        value: brans,
                        child: Text(brans),
                      );
                    }).toList(),
                    onChanged: (yeniDeger) {
                      setState(() {
                        secilenBrans = yeniDeger;
                      });
                    },
                  ),
                ),
              ...aktifDersler.map((ders) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: dersNetControllers[ders],
                    decoration: InputDecoration(
                      labelText: "$ders Neti ",
                      labelStyle: TextStyle(color: Colors.black),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                );
              }),
              ElevatedButton(
                onPressed: () async {
                  if (adController.text.isNotEmpty && secilenTur != null) {
                    Map<String, double> girilenNetler = {};
                    dersNetControllers.forEach((ders, controller) {
                      if (controller.text.isNotEmpty) {
                        girilenNetler[ders] =
                            double.tryParse(controller.text) ?? 0.0;
                      }
                    });

                    final yeniSinav = Sinav(
                      sinavId: DateTime.now().millisecondsSinceEpoch.toString(),
                      sinavAd: adController.text,
                      sinavTuru: secilenTur!,
                      sinavBrans: secilenBrans,
                      netler: girilenNetler,
                    );

                    await SinavRepository().addSinav(yeniSinav);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Sınav başarıyla kaydedildi")),
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Lütfen sınav adı ve türü seçin")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: Size(300, 50),
                ),
                child: Text("Sınavı Kaydet"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

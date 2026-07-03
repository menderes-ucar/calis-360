import 'package:flutter/material.dart';
import '../../models/soru.dart';
import '../../repositories/soru_repo.dart';

class SoruEkle extends StatefulWidget {
  const SoruEkle({super.key});

  @override
  State<SoruEkle> createState() => _SoruEkleState();
}

class _SoruEkleState extends State<SoruEkle> {
  final List<String> dersler = [
    "Türkçe","Tarih","Coğrafya","Felsefe","Din","Matematik","Geometri",
    "Fizik", "Kimya", "Biyoloji"
  ];

  String? secilenDers;

  final TextEditingController konuController = TextEditingController();
  final TextEditingController soruController = TextEditingController();
  final TextEditingController cevapController = TextEditingController();

  final SoruRepository _soruRepo = SoruRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Soru Ekle"),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<String>(
                hint: Text("Ders Seç"),
                value: secilenDers,
                isExpanded: true,
                items: dersler.map((ders) {
                  return DropdownMenuItem(
                    value: ders,
                    child: Text(ders),
                  );
                }).toList(),
                onChanged: (yeniDeger) {
                  setState(() {
                    secilenDers = yeniDeger;
                  });
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: konuController,
                decoration: InputDecoration(
                  labelText: "Konu Gir",
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: soruController,
                decoration: InputDecoration(
                  labelText: "Soruyu Yaz",
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.photo_camera),
                    onPressed: () {},
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: cevapController,
                decoration: InputDecoration(
                  labelText: "Cevabı Yaz",
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (secilenDers != null &&
                      konuController.text.isNotEmpty &&
                      soruController.text.isNotEmpty &&
                      cevapController.text.isNotEmpty) {

                    final yeniSoru = Soru(
                      soruId: DateTime.now().millisecondsSinceEpoch.toString(),
                      soruAd: soruController.text,
                      soruDers: secilenDers!,
                      soruKonu: konuController.text,
                      soruCevap: cevapController.text,
                    );

                    await _soruRepo.addSoru(yeniSoru);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Soru başarıyla kaydedildi")),
                    );
                    Navigator.pop(context);
                    soruController.clear();
                    cevapController.clear();
                    konuController.clear();
                    setState(() {
                      secilenDers = null;
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Lütfen tüm alanları doldurun.")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text("Soruyu Kaydet"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

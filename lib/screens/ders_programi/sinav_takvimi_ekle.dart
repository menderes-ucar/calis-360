import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/sinav_takvimi.dart';
import '../../repositories/sinav_takvimi_repo.dart';

class SinavTakvimiEkle extends StatefulWidget {
  const SinavTakvimiEkle({super.key});

  @override
  State<SinavTakvimiEkle> createState() => _SinavTakvimiEkleState();
}

class _SinavTakvimiEkleState extends State<SinavTakvimiEkle> {
  final List<String> sinavTurleri = ["TYT", "AYT"];
  String? sinavTuru;
  DateTime? sinavZamani;

  final repo = SinavTakvimiRepository();

  void sinavEkle() async {
    if (sinavZamani == null || sinavTuru == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tür ve zamanı seçmelisin!")),
      );
      return;
    }

    final docRef = FirebaseFirestore.instance.collection("sinavTakvimi").doc();

    final yeniSinavTakvimi = SinavTakvimi(
      sinavId: docRef.id,
      sinavTur: sinavTuru!,
      sinavZamani: sinavZamani!,
    );

    await repo.addSinavProgram(yeniSinavTakvimi);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sınav eklendi ✅")),
    );

    Navigator.pop(context);
  }

  Future<void> tarihSec() async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (secilen != null) {
      setState(() {
        sinavZamani = secilen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sınav Ekle"),
        backgroundColor: const Color(0xFFE4080A),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE4080A), Color(0xFFFE9900), Color(0xFFFFDE59)],
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: DropdownButton<String>(
                hint: const Text("Sınav Türü Seç"),
                value: sinavTuru,
                isExpanded: true,
                items: sinavTurleri.map((tur) {
                  return DropdownMenuItem(
                    value: tur,
                    child: Text(tur),
                  );
                }).toList(),
                onChanged: (yeniDeger) {
                  setState(() {
                    sinavTuru = yeniDeger;
                  });
                },
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: tarihSec,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(300, 50),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: Text(
                sinavZamani == null ? "Tarih Seç" : sinavZamani.toString(),
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: sinavEkle,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text("Kaydet"),
            ),
            Expanded(
              child: StreamBuilder<List<SinavTakvimi>>(
                stream: SinavTakvimiRepository().getDers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Hata: ${snapshot.error}"));
                  }

                  final sinavlar = snapshot.data ?? [];
                  if (sinavlar.isEmpty) {
                    return const Center(child: Text("Henüz sınav eklenmemiş"));
                  }

                  return ListView.builder(
                    itemCount: sinavlar.length,
                    itemBuilder: (context, index) {
                      final sinav = sinavlar[index];
                      return ListTile(
                        title: Text("${sinav.sinavTur} - ${sinav.sinavZamani.toLocal()}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.blue),
                          onPressed: () async {
                            await SinavTakvimiRepository().deleteSinav(sinav.sinavId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Sınav silindi")),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

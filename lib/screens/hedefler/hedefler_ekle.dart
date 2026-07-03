import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/hedef.dart';

class HedeflerEkle extends StatefulWidget {
  const HedeflerEkle({super.key});

  @override
  State<HedeflerEkle> createState() => _HedeflerEkleState();
}

class _HedeflerEkleState extends State<HedeflerEkle> {
  final List<String> hedefZamanlari = [
    "Günlük Hedef",
    "Haftalık Hedef",
    "Aylık Hedef"
  ];

  final TextEditingController hedefText = TextEditingController();
  final TextEditingController hedefNoteText = TextEditingController();

  String? hedefZamani;
  DateTime? secilenTarih;

  Future<void> tarihSec(BuildContext context) async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        secilenTarih = picked;
      });
    }
  }

  void hedefEkle() async {
    if (hedefText.text.isEmpty || hedefNoteText.text.isEmpty || hedefZamani == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hedef, not ve zamanı seçmelisin!")),
      );
      return;
    }

    if (hedefZamani == "Günlük Hedef") {
      secilenTarih = DateTime.now();
    }

    // Kullanıcının UID'si altına ekleme
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("hedefler")
        .doc(); // otomatik ID

    final yeniHedef = Hedef(
      hedefId: docRef.id,
      hedefAd: hedefText.text,
      hedefNote: hedefNoteText.text,
      hedefTarihi: secilenTarih ?? DateTime.now(),
      hedefZamani: hedefZamani!,
    );

    await docRef.set({
      "hedefAd": yeniHedef.hedefAd,
      "hedefNote": yeniHedef.hedefNote,
      "hedefTarihi": yeniHedef.hedefTarihi,
      "hedefZamani": yeniHedef.hedefZamani,
    });

    setState(() {
      hedefText.clear();
      hedefNoteText.clear();
      hedefZamani = null;
      secilenTarih = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Hedef eklendi ✅")),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hedef Ekle"),
        backgroundColor: const Color(0xFFE4080A),
      ),
      body: Container(
        width: double.infinity,
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: hedefText,
                decoration: const InputDecoration(
                  labelText: "Hedef Adı",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: hedefNoteText,
                decoration: const InputDecoration(
                  labelText: "Hedef Notu",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButton<String>(
                hint: const Text("Hedef Zamanı Seç"),
                value: hedefZamani,
                isExpanded: true,
                items: hedefZamanlari.map((zaman) {
                  return DropdownMenuItem(
                    value: zaman,
                    child: Text(zaman),
                  );
                }).toList(),
                onChanged: (yeniDeger) async {
                  setState(() {
                    hedefZamani = yeniDeger;
                  });
                  if (yeniDeger == "Haftalık Hedef" || yeniDeger == "Aylık Hedef") {
                    await tarihSec(context);
                  }
                },
              ),
            ),
            if (secilenTarih != null)
              Text(
                "Seçilen Tarih: ${secilenTarih!.day}/${secilenTarih!.month}/${secilenTarih!.year}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ElevatedButton(
              onPressed: hedefEkle,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text("Ekle"),
            ),
          ],
        ),
      ),
    );
  }
}

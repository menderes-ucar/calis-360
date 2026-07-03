import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zirve/screens/sorusınav/sınav_ekle.dart';
import 'package:zirve/screens/sorusınav/soru_ekle.dart';
import '../../models/soru.dart';
import '../../models/sınav.dart';
import '../../repositories/sinav_repo.dart';
import '../../repositories/soru_repo.dart';

class Netler {
  List<double> tytNetler = [];
  List<double> aytNetler = [];
}

final netler = Netler();

class SoruSinavTakibi extends StatefulWidget {
  const SoruSinavTakibi({super.key});

  @override
  State<SoruSinavTakibi> createState() => _SoruSinavTakibiState();
}

class _SoruSinavTakibiState extends State<SoruSinavTakibi> {
  double tytOrtalama = 0;
  double aytOrtalama = 0;

  @override
  void initState() {
    super.initState();
    ortalamaHesapla();

    // Soru netlerini al
    SoruRepository().getSorular().listen((sorular) {
      netler.tytNetler =
          sorular.map((s) => double.tryParse(s.soruCevap) ?? 0).toList();
      ortalamaHesapla();
    });

    // Sınav netlerini al ve ortalamayı ayrı hesapla
    SinavRepository().getSinavlar().listen((sinavlar) {
      final tytNetlerList = sinavlar
          .where((s) => s.sinavTuru == "TYT")
          .map((s) => s.netler.values.reduce((a, b) => a + b))
          .toList();
      final aytNetlerList = sinavlar
          .where((s) => s.sinavTuru == "AYT")
          .map((s) => s.netler.values.reduce((a, b) => a + b))
          .toList();

      setState(() {
        netler.tytNetler = tytNetlerList;
        netler.aytNetler = aytNetlerList;
        ortalamaHesapla();
      });
    });
  }

  void ortalamaHesapla() {
    setState(() {
      tytOrtalama = netler.tytNetler.isEmpty
          ? 0
          : netler.tytNetler.reduce((a, b) => a + b) / netler.tytNetler.length;

      aytOrtalama = netler.aytNetler.isEmpty
          ? 0
          : netler.aytNetler.reduce((a, b) => a + b) / netler.aytNetler.length;
    });
  }

  void _showUpdateSoruDialog(BuildContext context, Soru soru) {
    final adController = TextEditingController(text: soru.soruAd);
    final dersController = TextEditingController(text: soru.soruDers);
    final konuController = TextEditingController(text: soru.soruKonu);
    final cevapController = TextEditingController(text: soru.soruCevap);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Soruyu Güncelle"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: adController, decoration: const InputDecoration(labelText: "Soru Adı")),
              TextField(controller: dersController, decoration: const InputDecoration(labelText: "Ders")),
              TextField(controller: konuController, decoration: const InputDecoration(labelText: "Konu")),
              TextField(controller: cevapController, decoration: const InputDecoration(labelText: "Cevap")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SoruRepository().updateSoru(Soru(
                    soruId: soru.soruId,
                    soruAd: adController.text.trim(),
                    soruDers: dersController.text.trim(),
                    soruKonu: konuController.text.trim(),
                    soruCevap: cevapController.text.trim(),
                  ));
                  setState(() {}); // UI yenile
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Soru başarıyla güncellendi")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Hata: $e")),
                  );
                }
              },
              child: const Text("Kaydet"),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateSinavDialog(BuildContext context, Sinav sinav) {
    final adController = TextEditingController(text: sinav.sinavAd);
    final turuController = TextEditingController(text: sinav.sinavTuru);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Sınavı Güncelle"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: adController, decoration: const InputDecoration(labelText: "Sınav Adı")),
              TextField(controller: turuController, decoration: const InputDecoration(labelText: "Türü")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SinavRepository().updateSinav(Sinav(
                    sinavId: sinav.sinavId,
                    sinavAd: adController.text.trim(),
                    sinavTuru: turuController.text.trim(),
                    netler: sinav.netler,
                    sinavBrans: sinav.sinavBrans,
                  ));
                  setState(() {}); // UI yenile
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Sınav başarıyla güncellendi")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Hata: $e")),
                  );
                }
              },
              child: const Text("Kaydet"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double mediaWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sınav ve Sorular"),
        backgroundColor: const Color(0xFF32FDA2),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => logout(context)),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF32FDA2), Color(0xFF13D8CA), Color(0xFF09adfe)],
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("ORTALAMA NET", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text("TYT Ortalama: ${tytOrtalama.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("AYT Ortalama: ${aytOrtalama.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoruEkle())),
                            style: TextButton.styleFrom(foregroundColor: Colors.black, minimumSize: Size(mediaWidth / 3, 60)),
                            child: const Text("Soru Ekle", style: TextStyle(fontSize: 20)),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SinavEkle())),
                            style: TextButton.styleFrom(foregroundColor: Colors.black, minimumSize: Size(mediaWidth / 3, 60)),
                            child: const Text("Sınav Ekle", style: TextStyle(fontSize: 20)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // SORULAR
                    Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black, width: 2)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("SORULAR", style: TextStyle(fontSize: 20)),
                            const SizedBox(height: 8),
                            StreamBuilder<List<Soru>>(
                              stream: SoruRepository().getSorular(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text("Henüz soru eklenmemiş", style: TextStyle(fontSize: 16)),
                                  );
                                }
                                final sorular = snapshot.data!;
                                return Column(
                                  children: sorular.map((soru) {
                                    return ListTile(
                                      title: Text(soru.soruAd),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Ders: ${soru.soruDers}"),
                                          Text("Konu: ${soru.soruKonu}"),
                                          Text("Cevap: ${soru.soruCevap}"),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () => _showUpdateSoruDialog(context, soru),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () async {
                                              await SoruRepository().deleteSoru(soru.soruId);
                                              setState(() {});
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Soru silindi")));
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // SINAVLAR
                    Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black, width: 2)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("SINAVLAR", style: TextStyle(fontSize: 20)),
                            const SizedBox(height: 8),
                            StreamBuilder<List<Sinav>>(
                              stream: SinavRepository().getSinavlar(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text("Henüz sınav eklenmemiş", style: TextStyle(fontSize: 16)),
                                  );
                                }
                                final sinavlar = snapshot.data!;
                                return Column(
                                  children: sinavlar.map((sinav) {
                                    return ExpansionTile(
                                      title: Text(sinav.sinavAd),
                                      subtitle: Text("Türü: ${sinav.sinavTuru}"),
                                      children: [
                                        if (sinav.sinavBrans != null) Text("Branş: ${sinav.sinavBrans}"),
                                        ...sinav.netler.entries.map((e) => Text("${e.key}: ${e.value.toStringAsFixed(2)} net")),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              onPressed: () => _showUpdateSinavDialog(context, sinav),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () async {
                                                await SinavRepository().deleteSinav(sinav.sinavId);
                                                setState(() {});
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sınav silindi")));
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacementNamed("/login");
  }
}

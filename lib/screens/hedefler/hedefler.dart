import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zirve/repositories/hedef_repo.dart';
import 'package:zirve/screens/hedefler/hedefler_ekle.dart';
import '../../models/hedef.dart';

class Hedefler extends StatefulWidget {
  const Hedefler({super.key});

  @override
  State<Hedefler> createState() => _HedeflerState();
}

class _HedeflerState extends State<Hedefler> {
  bool isChecked = false;
  String seciliFiltre = "Hepsi";

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HEDEFLER"),
        backgroundColor: const Color(0xFF32FDA2),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
            tooltip: "Çıkış Yap",
          ),
        ],
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF32FDA2),
              Color(0xFF13D8CA),
              Color(0xFF09adfe),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: StreamBuilder<List<Hedef>>(
                stream: HedefRepository().getHedef(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final hedefler = snapshot.data!;
                  final gunluk = hedefler.where((h) => h.hedefZamani == "Günlük Hedef").toList();
                  final gunlukTamam = gunluk.where((h) => h.tamamlandi).length;
                  final haftalik = hedefler.where((h) => h.hedefZamani == "Haftalık Hedef").toList();
                  final haftalikTamam = haftalik.where((h) => h.tamamlandi).length;
                  final aylik = hedefler.where((h) => h.hedefZamani == "Aylık Hedef").toList();
                  final aylikTamam = aylik.where((h) => h.tamamlandi).length;
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Günlük Hedef", style: TextStyle(fontSize: 20)),
                          Text("$gunlukTamam/${gunluk.length}"),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: gunluk.isEmpty ? 0 : gunlukTamam / gunluk.length,
                        backgroundColor: Colors.grey[300],
                        color: Colors.black,
                        minHeight: 10,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Haftalık Hedef", style: TextStyle(fontSize: 20)),
                          Text("$haftalikTamam/${haftalik.length}"),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: haftalik.isEmpty ? 0 : haftalikTamam / haftalik.length,
                        backgroundColor: Colors.grey[300],
                        color: Colors.black,
                        minHeight: 10,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Aylık Hedef", style: TextStyle(fontSize: 20)),
                          Text("$aylikTamam/${aylik.length}"),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: aylik.isEmpty ? 0 : aylikTamam / aylik.length,
                        backgroundColor: Colors.grey[300],
                        color: Colors.black,
                        minHeight: 10,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 60,
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            seciliFiltre = "Hepsi";
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Bütün Hedefler", style: TextStyle(fontSize: 20)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            seciliFiltre = "Günlük Hedef";
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Günlük Hedef", style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            seciliFiltre = "Haftalık Hedef";
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Haftalık Hedef", style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 15),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            seciliFiltre = "Aylık Hedef";
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Aylık Hedef", style: TextStyle(fontSize: 20)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Hedefler",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<List<Hedef>>(
                        stream: HedefRepository().getHedef(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(
                              child: Text("Henüz hedef eklenmemiş", style: TextStyle(fontSize: 16)),
                            );
                          }
                          final hedefler = snapshot.data!.where((h) => seciliFiltre == "Hepsi" || h.hedefZamani == seciliFiltre).toList();
                          return ListView.builder(
                            itemCount: hedefler.length,
                            itemBuilder: (context, index) {
                              final hedef = hedefler[index];
                              return ListTile(
                                title: Text(hedef.hedefAd),
                                subtitle: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Note: ${hedef.hedefNote}"),
                                    Text("Tarih: ${hedef.hedefTarihi}"),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        await HedefRepository().deleteHedef(hedef.hedefId);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hedef silindi")));
                                      },
                                    ),
                                    Checkbox(
                                      value: hedef.tamamlandi,
                                      onChanged: (value) async {
                                        if (value != null) {
                                          await HedefRepository().updateTamamlandi(hedef.hedefId, value);
                                          setState(() {});
                                        }
                                      },
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
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
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const HedeflerEkle()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zirve/repositories/dersProgrami_repo.dart';
import 'package:zirve/screens/ders_programi/dersprogrami_ekle.dart';
import '../../models/dersProgrami.dart';
import '../../widgets/ders_program_widget/takvim_widget.dart';
import '../../models/sinav_takvimi.dart';
import '../../repositories/sinav_takvimi_repo.dart';
import 'sinav_takvimi_ekle.dart';

class Dersprogrami extends StatefulWidget {
  const Dersprogrami({super.key});

  @override
  State<Dersprogrami> createState() => _DersprogramiState();
}

class _DersprogramiState extends State<Dersprogrami> {
  String seciliFiltre = "Pazartesi";

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ders Programı"),
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
        width: double.infinity,
        height: double.infinity,
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
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            Row(
              children: [
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const SinavTakvimiEkle()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    "Sınav Takvimi Ekle",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            StreamBuilder<List<SinavTakvimi>>(
              stream: SinavTakvimiRepository().getDers(),
              builder: (context, snapshot) {
                final sinavlar = snapshot.data ?? [];
                return SinavTakvimiWidget(sinavlar: sinavlar);
              },
            ),
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var gun in [
                    "Pazartesi",
                    "Salı",
                    "Çarşamba",
                    "Perşembe",
                    "Cuma",
                    "Cumartesi",
                    "Pazar"
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            seciliFiltre = gun;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          gun,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    )
                ],
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: Colors.transparent,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.black, width: 2),
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 300),
                width: double.infinity,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "PROGRAM",
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                    StreamBuilder<List<DersProgram>>(
                      stream: DersProgramiRepository().getDersProgram(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text("Hata: ${snapshot.error}"));
                        }

                        final tumProgram = snapshot.data ?? [];
                        if (tumProgram.isEmpty) {
                          return const Center(
                              child: Text("Henüz Program eklenmemiş"));
                        }

                        final fSel = seciliFiltre.trim().toLowerCase();
                        final filtered = tumProgram
                            .where((p) =>
                        p.dersProgramGun.trim().toLowerCase() ==
                            fSel)
                            .toList();

                        if (filtered.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text(
                                "Bu güne ait kayıt yok. Başka günü seç veya yeni kayıt ekle."),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final dp = filtered[index];
                            return ListTile(
                              title: Text(
                                dp.dersProgramDersAd,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Çalışılacak Gün: ${dp.dersProgramGun}",
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.black),
                                  ),
                                  Text(
                                    "Çalışılacak Konu: ${dp.dersProgramKonuAd}",
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.black),
                                  ),
                                  Text(
                                    "Çalışılacak Saat: ${dp.dersProgramSaat}",
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.black),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      await DersProgramiRepository()
                                          .deleteDersProgram(dp.dersProgramId);
                                      setState(() {}); // silme sonrası listeyi yenile
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Program silindi")));
                                    },
                                  ),
                                  Checkbox(
                                    value: dp.tamamlandi,
                                    onChanged: (v) async {
                                      if (v != null) {
                                        await DersProgramiRepository()
                                            .updateTamamlandi(dp.dersProgramId, v);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const DersprogramiEkle()),
          );
          if (result == true) {
            setState(() {}); // Yeni veri eklendiğinde sayfayı yenile
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

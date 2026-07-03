import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Ayarlar extends StatefulWidget {
  const Ayarlar({super.key});

  @override
  State<Ayarlar> createState() => _AyarlarState();
}

class _AyarlarState extends State<Ayarlar> {

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacementNamed("/login");
  }

  Future<void> deleteAccount(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hesabınız başarıyla silindi.")),
        );
        Navigator.of(context).pushReplacementNamed("/login");
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: ${e.message}")),
      );
    }
  }

  final List<Map<String, dynamic>> features = [
    {
      "icon": Icons.family_restroom,
      "title": "Ebeveyn Erişimi",
      "subtitle": "Ebeveynler öğrencinin geçmiş sınavlarını görüntüleyebilecek."
    },
    {
      "icon": Icons.person,
      "title": "Öğretmen Erişimi",
      "subtitle": "Öğretmenler öğrencilerin ilerlemesini ve performansını takip edebilecek."
    },
    {
      "icon": Icons.photo_camera,
      "title": "Fotoğraf ile Soru Ekleme",
      "subtitle": "Soruları fotoğraf olarak ekleyebilir ve daha kolay paylaşabilirsiniz."
    },
    {
      "icon": Icons.note,
      "title": "Her Ders için Özel Not Sayfaları",
      "subtitle": "Öğrenciler her ders için ayrı not sayfaları oluşturabilecek."
    },
    {
      "icon": Icons.bar_chart,
      "title": "Ders ve Sınavlar için Özel Grafikler",
      "subtitle": "Performans ve istatistikler görsel olarak takip edilebilecek."
    },
    {
      "icon": Icons.block,
      "title": "Reklamsız Kullanım",
      "subtitle": "Uygulamayı reklamsız ve daha temiz bir deneyimle kullanabilirsiniz."
    },
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ayarlar", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF232FDA2), Color(0xFF13D8CA), Color(0xFF09ADFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "Premium Özellik ile Gelecek Olan Özellikler",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: features.length,
                itemBuilder: (context, index) {
                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    color: Colors.white.withOpacity(0.85),
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: ListTile(
                      leading: Icon(features[index]["icon"],
                          color: Colors.black, size: 30),
                      title: Text(
                        features[index]["title"],
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        features[index]["subtitle"],
                        style:
                        const TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => logout(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Çıkış Yap",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => deleteAccount(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Hesabımı Sil",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

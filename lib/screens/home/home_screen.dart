import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zirve/screens/home/home_hedef_ekle.dart';
import '../../widgets/home_widget/home_widget.dart';
import '../../widgets/home_widget/home_widget_sayim.dart';
import 'package:zirve/repositories/home_hedef_repo.dart';
import 'package:zirve/models/home_hedef_ekle.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final repo = HomeHedefRepository();
  int net = 0;
  String uni = "";
  String bolum = "";

  final String userId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    double mediaHeight = MediaQuery.of(context).size.height;
    double mediaWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        backgroundColor: const Color(0xFF13D8CA),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
            tooltip: "Çıkış Yap",
          ),
        ],
      ),
      body: Container(
        height: mediaHeight,
        width: mediaWidth,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF232FDA2), Color(0xFF13D8CA), Color(0xFF09ADFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.lightBlue.withOpacity(0.4),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(15),
              child: CountdownWidget(),
            ),
            Container(
              color: Colors.lightBlueAccent.withOpacity(0.4),
              padding: const EdgeInsets.all(15),
              child: BannerWidgetArea(),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: StreamBuilder<HomeHedef?>(
                stream: repo.getHomeHedefForCurrentUser(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final hedef = snapshot.data;

                  if (hedef == null) {
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 6,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black, Colors.black12],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.touch_app, color: Colors.white, size: 30),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Hedef netini, bölümünü ve üniversiteni eklemek için sağ alttaki butona bas!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_downward, color: Colors.white, size: 30),
                          ],
                        ),
                      ),
                    );
                  }

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 6,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black, Colors.black12],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Hedef Net: ${hedef.net}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "${hedef.uni} - ${hedef.bolum}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => HomeHedefEkle()),
          );

          if (result != null && result is Map<String, String>) {
            await repo.addOrUpdateHedefForCurrentUser(
              net: int.tryParse(result["hedefNet"] ?? "0") ?? 0,
              uni: result["universite"] ?? "",
              bolum: result["bolum"] ?? "",
            );
          }
        },
        child: const Icon(Icons.add),
      ),

    );
  }
}

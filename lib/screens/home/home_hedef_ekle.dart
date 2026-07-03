import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zirve/models/home_hedef_ekle.dart';
import 'package:zirve/repositories/home_hedef_repo.dart';

class HomeHedefEkle extends StatefulWidget {
  const HomeHedefEkle({super.key});

  @override
  State<HomeHedefEkle> createState() => _HomeHedefEkleState();
}

class _HomeHedefEkleState extends State<HomeHedefEkle> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController netController = TextEditingController();
  final TextEditingController uniController = TextEditingController();
  final TextEditingController bolumController = TextEditingController();

  final repo = HomeHedefRepository();

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text("Hedef Ekle/Güncelle"),
          backgroundColor: Color(0xFFE4080A)),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE4080A), Color(0xFFFE9900), Color(0xFFFFDE59)],
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: TextFormField(
                      controller: netController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: "Hedef Net"),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return "Net giriniz";
                        if (int.tryParse(value) == null) return "Sayı giriniz";
                        return null;
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: TextFormField(
                      controller: uniController,
                      decoration: InputDecoration(labelText: "Üniversite"),
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? "Üniversite giriniz"
                          : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: TextFormField(
                      controller: bolumController,
                      decoration: InputDecoration(labelText: "Bölüm"),
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? "Bölüm giriniz"
                          : null,
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          await repo.addOrUpdateHedefForCurrentUser(
                            net: int.parse(netController.text),
                            uni: uniController.text,
                            bolum: bolumController.text,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Hedef kaydedildi")),
                          );
                        }
                      },
                      child: const Text("Kaydet"),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<HomeHedef?>(
                stream: repo.getHomeHedefForCurrentUser(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    return Center(child: Text("Henüz hedef eklenmemiş"));
                  }

                  final hedef = snapshot.data!;
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text("Net: ${hedef.net}"),
                      subtitle: Text("${hedef.uni} - ${hedef.bolum}"),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await repo.deleteHomeHedefForCurrentUser();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Hedef silindi")),
                          );
                        },
                      ),
                      onTap: () {
                        netController.text = hedef.net.toString();
                        uniController.text = hedef.uni;
                        bolumController.text = hedef.bolum;
                      },
                    ),
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

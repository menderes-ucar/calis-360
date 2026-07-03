import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // REGISTER (Kayıt Ol)
  Future<User?> register(String email, String password) async {
    try {
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Register error: $e");
      return null;
    }
  }

  // LOGIN (Giriş Yap)
  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Login error: $e");
      return null;
    }
  }

  // LOGOUT (Çıkış Yap)
  Future<void> logout() async {
    await _auth.signOut();
  }

  // GET CURRENT USER (O an giriş yapan kullanıcıyı döner)
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}

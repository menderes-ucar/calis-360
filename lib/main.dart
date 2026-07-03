import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zirve/screens/autherization/giris.dart';
import 'package:zirve/screens/autherization/kayit.dart';
import 'package:zirve/screens/ders_programi/DersProgrami.dart';
import 'package:zirve/screens/hedefler/hedefler.dart';
import 'package:zirve/screens/home/home_screen.dart';
import 'package:zirve/screens/ayarlar.dart';
import 'package:zirve/screens/app_view.dart';
import 'package:zirve/screens/sorus%C4%B1nav/soru_s%C4%B1nav_takibi.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

/// Helper class for GoRouter to listen to FirebaseAuth changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
      redirect: (context, state) {
        final user = FirebaseAuth.instance.currentUser;
        final location = state.uri.toString();
        final loggingIn = location == '/login' || location == '/register';

        if (user == null && !loggingIn) return '/login';
        if (user != null && loggingIn) return '/home';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppView(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/dersprogrami',
                  builder: (context, state) => const Dersprogrami(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/hedefler',
                  builder: (context, state) => const Hedefler(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/sorular',
                  builder: (context, state) => const SoruSinavTakibi(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/ayarlar',
                  builder: (context, state) => const Ayarlar(),
                ),
              ],
            ),
          ],
        ),
      ],
      initialLocation: '/login',
    );

    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}


import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zirve/screens/ders_programi/DersProgrami.dart';
import 'package:zirve/screens/ayarlar.dart';
import 'package:zirve/screens/hedefler/hedefler.dart';
import 'package:zirve/screens/home/home_screen.dart';
import 'package:zirve/screens/app_view.dart';
import 'package:zirve/screens/sorus%C4%B1nav/soru_s%C4%B1nav_takibi.dart'; // <-- AppView doğru dosyada mı?


final _routerKey = GlobalKey<NavigatorState>();

class AppRoutes {
  static const anasayfa = '/anasayfa';
  static const dersprogrami = '/dersprogrami';
  static const hedefler = '/hedefler';
  static const sorular = '/sorular';
  static const ayarlar = '/ayarlar';

}

final router = GoRouter(
  navigatorKey: _routerKey,
  initialLocation: AppRoutes.anasayfa,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppView(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.anasayfa,
              builder: (context, state) => HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.dersprogrami,
              builder: (context, state) => Dersprogrami(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.hedefler,
              builder: (context, state) => Hedefler(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.sorular,
              builder: (context, state) => SoruSinavTakibi(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.ayarlar,
              builder: (context, state) => Ayarlar(),
            ),
          ],
        ),
      ],
    ),
  ],
);

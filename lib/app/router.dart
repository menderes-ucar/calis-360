import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai_solver/presentation/screens/ai_solver_screen.dart';
import '../features/analytics/presentation/screens/analytics_screen.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/billing/presentation/screens/billing_screen.dart';
import '../features/content/presentation/screens/content_home_screen.dart';
import '../features/content/presentation/screens/content_topic_detail_screen.dart';
import '../features/content/presentation/screens/content_topics_screen.dart';
import '../features/content/presentation/screens/content_units_screen.dart';
import '../features/gamification/presentation/screens/leaderboard_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../screens/app_view.dart';
import '../screens/autherization/giris.dart';
import '../screens/autherization/kayit.dart';
import '../screens/ayarlar.dart';
import '../screens/ders_programi/DersProgrami.dart';
import '../screens/hedefler/hedefler.dart';
import '../screens/home/home_screen.dart';
import '../screens/soru_sinav/soru_sinav_takibi.dart';

class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const aiSolver = '/ai-solver';
  static const analytics = '/analytics';
  static const leaderboard = '/leaderboard';
  static const profile = '/profile';

  // Ana bottom navigation dışında kalan mevcut özellikler korunur ve
  // ilgili sayfalardan açılır.
  static const content = '/calis';
  static const dersProgrami = '/dersprogrami';
  static const hedefler = '/hedefler';
  static const sorular = '/sorular';
  static const ayarlar = '/ayarlar';
  static const billing = '/billing';

  static String contentUnitsPath(String subjectId) => '/calis/$subjectId';

  static String contentTopicsPath(String subjectId, String unitId) =>
      '/calis/$subjectId/$unitId';

  static String contentTopicDetailPath(
    String subjectId,
    String unitId,
    String topicId,
  ) => '/calis/$subjectId/$unitId/$topicId';
}

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

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final refreshListenable = GoRouterRefreshStream(authRepository.userChanges());

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: authRepository.currentUser == null
        ? AppRoutes.login
        : AppRoutes.home,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final user = authRepository.currentUser;
      final path = state.uri.path;
      final isAuthRoute = path == AppRoutes.login || path == AppRoutes.register;

      if (user == null && !isAuthRoute) {
        return AppRoutes.login;
      }

      if (user != null && isAuthRoute) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
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
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.aiSolver,
                builder: (context, state) => const AiSolverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.analytics,
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.leaderboard,
                builder: (context, state) => const LeaderboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.content,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ContentHomeScreen(),
        routes: [
          GoRoute(
            path: ':subjectId',
            builder: (context, state) => ContentUnitsScreen(
              subjectId: state.pathParameters['subjectId']!,
              subjectName: state.extra as String?,
            ),
            routes: [
              GoRoute(
                path: ':unitId',
                builder: (context, state) => ContentTopicsScreen(
                  subjectId: state.pathParameters['subjectId']!,
                  unitId: state.pathParameters['unitId']!,
                  unitName: state.extra as String?,
                ),
                routes: [
                  GoRoute(
                    path: ':topicId',
                    builder: (context, state) => ContentTopicDetailScreen(
                      subjectId: state.pathParameters['subjectId']!,
                      unitId: state.pathParameters['unitId']!,
                      topicId: state.pathParameters['topicId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.dersProgrami,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const Dersprogrami(),
      ),
      GoRoute(
        path: AppRoutes.sorular,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SoruSinavTakibi(),
      ),
      GoRoute(
        path: AppRoutes.hedefler,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const Hedefler(),
      ),
      GoRoute(
        path: AppRoutes.ayarlar,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const Ayarlar(),
      ),
      GoRoute(
        path: AppRoutes.billing,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BillingScreen(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refreshListenable.dispose();
  });

  return router;
});

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppView extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppView({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A84FF), // Scaffold arka planı mavi
      body: navigationShell,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF040505), // Alt bar mavi
          surfaceTintColor: Colors.transparent,      // Material3 beyaz overlay’i engeller
          indicatorColor: Colors.transparent,        // Seçili arka planı kapatır
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
            }
            return const TextStyle(color: Colors.white70);
          }),
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const IconThemeData(color: Colors.white);
            }
            return const IconThemeData(color: Colors.white70);
          }),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(index);
          },
          destinations: [
            _menuItem(label: 'Home', icon: Icons.home),
            _menuItem(label: 'Ders', icon: Icons.calendar_today),
            _menuItem(label: 'Hedef', icon: Icons.check_box_outlined),
            _menuItem(label: 'Sınav', icon: Icons.book),
            _menuItem(label: 'Ayarlar', icon: Icons.settings),
          ],
        ),
      ),
    );
  }

  NavigationDestination _menuItem({required String label, required IconData icon}) {
    return NavigationDestination(icon: Icon(icon), label: label);
  }
}

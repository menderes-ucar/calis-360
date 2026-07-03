import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppView extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppView({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold arka planı mavi
      backgroundColor: const Color(0xFF0A84FF),
      body: navigationShell,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0A84FF), // Alt bar mavi
          surfaceTintColor: Colors.transparent,      // Material3 beyaz overlay’i engelle
          indicatorColor: Colors.transparent,        // Seçili arka planı kapat
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
          onDestinationSelected: navigationShell.goBranch,
          destinations: [
            _menuItem(label: 'Anasayfa', icon: Icons.home),
            _menuItem(label: 'Ders Programi', icon: Icons.calendar_today_outlined),
            _menuItem(label: 'Soru Ekle', icon: Icons.add_circle_outline),
            _menuItem(label: 'Çalışma Takibi', icon: Icons.call_missed_outgoing_outlined),
            _menuItem(label: 'Ayarlar', icon: Icons.settings),
          ],
        ),
      ),
    );
  }

  NavigationDestination _menuItem({required String label, required IconData icon}) {
    return NavigationDestination(
      icon: Icon(icon),
      label: label,
    );
  }
}

import 'package:flutter/material.dart';

import '../state/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/close_app_scope.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const routeName = '/home';

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final screens = const [HomeScreen(), HistoryScreen(), ProfileScreen()];

    return CloseAppScope(
      onInterceptBack: () => session.onHomeBack?.call() ?? false,
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final index = session.shellTab;
          return Scaffold(
            body: SafeArea(bottom: false, child: screens[index]),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: AppShadows.lighter,
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: session.selectShellTab,
                destinations: const [
                  NavigationDestination(
                    key: Key('nav-home'),
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    key: Key('nav-history'),
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history_rounded),
                    label: 'History',
                  ),
                  NavigationDestination(
                    key: Key('nav-profile'),
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

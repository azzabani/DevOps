// lib/views/home/main_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_booking/providers/auth_provider.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:flutter_booking/services/notification_service.dart';
import 'package:flutter_booking/views/home/home_page.dart';
import 'package:flutter_booking/views/resources/resources_page.dart';
import 'package:flutter_booking/views/calendar/calendar_page.dart';
import 'package:flutter_booking/views/calendar/my_reservations_page.dart';
import 'package:flutter_booking/views/notifications/notifications_page.dart';
import 'package:flutter_booking/views/profile/profile_page.dart';
import 'package:flutter_booking/widgets/notification_badge.dart';
import 'package:flutter_booking/theme/app_theme.dart';
import 'package:flutter_booking/widgets/app_logo.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  final AuthService _authService = AuthService();
  String? _userRole;

  void setIndex(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadRole();
    // Charger le profil utilisateur dans le provider global
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        context.read<UserAuthProvider>().loadCurrentUser(uid);
      }
    });
  }

  Future<void> _loadRole() async {
    final role = await _authService.getUserRole();
    if (mounted) setState(() => _userRole = role);
  }

  List<_ShellPage> get _pages => [
        _ShellPage(
          label: 'Accueil',
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          page: HomePage(onNavigate: (i) => setState(() => _currentIndex = i)),
        ),
        _ShellPage(
          label: 'Ressources',
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2,
          page: const ResourcesPage(),
        ),
        _ShellPage(
          label: 'Calendrier',
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month,
          page: const CalendarPage(),
        ),
        _ShellPage(
          label: 'Réservations',
          icon: Icons.bookmark_border,
          activeIcon: Icons.bookmark,
          page: const MyReservationsPage(),
        ),
        _ShellPage(
          label: 'Notifications',
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications,
          page: const NotificationsPage(),
        ),
        _ShellPage(
          label: 'Profil',
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          page: ProfilePage(),
        ),
      ];

  List<NavigationDestination> _buildDestinations(List<_ShellPage> pages) {
    final userId = _authService.currentUser?.uid ?? '';
    return pages.map((p) {
      if (p.label == 'Notifications') {
        return NavigationDestination(
          icon: StreamBuilder<int>(
            stream: NotificationService().getUnreadCount(userId),
            builder: (ctx, snap) => NotificationBadge(
              count: snap.data ?? 0,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          selectedIcon: StreamBuilder<int>(
            stream: NotificationService().getUnreadCount(userId),
            builder: (ctx, snap) => NotificationBadge(
              count: snap.data ?? 0,
              child: const Icon(Icons.notifications, color: Color(0xFF2563EB)),
            ),
          ),
          label: 'Notifications',
        );
      }
      return NavigationDestination(
        icon: Icon(p.icon),
        selectedIcon: Icon(p.activeIcon, color: const Color(0xFF2563EB)),
        label: p.label,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: pages[_currentIndex].page,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primarySurface,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: _buildDestinations(pages),
        ),
      ),
      floatingActionButton: _userRole == 'admin'
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/admin'),
              icon: const Icon(Icons.admin_panel_settings_rounded),
              label: const Text('Admin',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
            )
          : _userRole == 'manager'
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.pushNamed(context, '/admin'),
                  icon: const Icon(Icons.manage_accounts_rounded),
                  label: const Text('Manager',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                )
              : null,
    );
  }
}

class _ShellPage {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;

  const _ShellPage({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });
}

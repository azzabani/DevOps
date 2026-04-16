// lib/views/admin/admin_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:flutter_booking/views/admin/admin_dashboard_page.dart';
import 'package:flutter_booking/views/admin/admin_resource_page.dart';
import 'package:flutter_booking/views/admin/admin_users_page.dart';
import 'package:flutter_booking/views/admin/admin_validate_page.dart';
import 'package:flutter_booking/views/admin/admin_reservations_page.dart';
import 'package:flutter_booking/theme/app_theme.dart';
import 'package:flutter_booking/widgets/falling_resources_bg.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await AuthService().getUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
        _isLoading = false;
        // Admin : 4 onglets | Manager : 2 onglets
        _tabController = TabController(
          length: role == 'admin' ? 5 : 2,
          vsync: this,
        );
      });
    }
  }

  @override
  void dispose() {
    if (!_isLoading) _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isAdmin = _userRole == 'admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isAdmin ? 'Administration' : 'Espace Manager'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          isScrollable: isAdmin,
          labelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 12),
          tabs: isAdmin
              ? const [
                  Tab(icon: Icon(Icons.dashboard_rounded), text: 'Dashboard'),
                  Tab(
                      icon: Icon(Icons.inventory_2_rounded),
                      text: 'Ressources'),
                  Tab(icon: Icon(Icons.people_rounded), text: 'Utilisateurs'),
                  Tab(
                      icon: Icon(Icons.pending_actions_rounded),
                      text: 'Validation'),
                  Tab(icon: Icon(Icons.list_alt_rounded), text: 'Toutes'),
                ]
              : const [
                  Tab(
                      icon: Icon(Icons.pending_actions_rounded),
                      text: 'À valider'),
                  Tab(icon: Icon(Icons.list_alt_rounded), text: 'Toutes'),
                ],
        ),
      ),
      body: Stack(
        children: [
          const FallingResourcesBg(count: 14, globalOpacity: 0.55),
          TabBarView(
        controller: _tabController,
        children: isAdmin
            ? const [
                AdminDashboardPage(),
                AdminResourcePage(),
                AdminUsersPage(),
                AdminValidatePage(),
                AdminReservationsPage(),
              ]
            : const [
                AdminValidatePage(),
                AdminReservationsPage(),
              ],
          ),
        ],
      ),
    );
  }
}

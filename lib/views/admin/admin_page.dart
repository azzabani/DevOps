// lib/views/admin/admin_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:flutter_booking/views/admin/admin_dashboard_page.dart';
import 'package:flutter_booking/views/admin/admin_resource_page.dart';
import 'package:flutter_booking/views/admin/admin_users_page.dart';
import 'package:flutter_booking/views/admin/admin_validate_page.dart';
import 'package:flutter_booking/views/admin/admin_reservations_page.dart';

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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isAdmin = _userRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(isAdmin ? 'Administration' : 'Espace Manager'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: isAdmin,
          tabs: isAdmin
              ? const [
                  Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
                  Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Ressources'),
                  Tab(icon: Icon(Icons.people_outline), text: 'Utilisateurs'),
                  Tab(icon: Icon(Icons.pending_actions), text: 'Validation'),
                  Tab(icon: Icon(Icons.list_alt), text: 'Toutes'),
                ]
              : const [
                  Tab(icon: Icon(Icons.pending_actions), text: 'À valider'),
                  Tab(icon: Icon(Icons.list_alt), text: 'Toutes'),
                ],
        ),
      ),
      body: TabBarView(
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
    );
  }
}

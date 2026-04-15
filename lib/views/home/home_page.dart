// lib/views/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  final void Function(int index)? onNavigate;
  const HomePage({super.key, this.onNavigate});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _userName;
  String? _userRole;
  int _pendingCount = 0;
  int _confirmedCount = 0;
  int _totalResources = 0;
  List<Map<String, dynamic>> _upcomingReservations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadUserData(),
      _loadStats(),
      _loadUpcoming(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) return;
    final data = await _authService.getUserData(user.uid);
    if (data != null && mounted) {
      setState(() {
        _userName = data['name'];
        _userRole = data['role'];
      });
    }
  }

  Future<void> _loadStats() async {
    final user = _authService.currentUser;
    if (user == null) return;
    try {
      // Charger toutes les réservations de l'utilisateur en une seule requête
      // pour éviter les index composites Firestore
      final results = await Future.wait([
        _firestore
            .collection('reservations')
            .where('userId', isEqualTo: user.uid)
            .get(),
        _firestore.collection('resources').get(),
      ]);

      int pending = 0;
      int confirmed = 0;
      for (final doc in results[0].docs) {
        final status = (doc.data())['status'] as String? ?? '';
        if (status == 'pending') pending++;
        if (status == 'confirmed') confirmed++;
      }

      if (mounted) {
        setState(() {
          _pendingCount = pending;
          _confirmedCount = confirmed;
          _totalResources = results[1].docs.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUpcoming() async {
    final user = _authService.currentUser;
    if (user == null) return;
    try {
      final now = DateTime.now();
      // Requête simple sans index composite — filtre côté client
      final snap = await _firestore
          .collection('reservations')
          .where('userId', isEqualTo: user.uid)
          .get();

      final upcoming = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final status = d['status'] as String? ?? '';
        if (status != 'pending' && status != 'confirmed') continue;

        final start = (d['startTime'] as Timestamp).toDate();
        if (!start.isAfter(now)) continue;

        String resourceName = d['resourceName'] as String? ?? '';
        if (resourceName.isEmpty && (d['resourceId'] as String? ?? '').isNotEmpty) {
          final rDoc = await _firestore
              .collection('resources')
              .doc(d['resourceId'])
              .get();
          if (rDoc.exists) resourceName = rDoc.data()?['name'] ?? 'Ressource';
        }
        if (resourceName.isEmpty) resourceName = 'Ressource';

        upcoming.add({
          'id': doc.id,
          'resourceName': resourceName,
          'startTime': start,
          'endTime': (d['endTime'] as Timestamp).toDate(),
          'status': status,
        });
      }

      // Tri côté client par startTime croissant, limité à 3
      upcoming.sort((a, b) =>
          (a['startTime'] as DateTime).compareTo(b['startTime'] as DateTime));
      final limited = upcoming.take(3).toList();
      if (mounted) setState(() => _upcomingReservations = limited);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _isLoading = true);
                await _loadAll();
              },
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildStatsRow(),
                        const SizedBox(height: 20),
                        _buildQuickActions(),
                        const SizedBox(height: 20),
                        _buildUpcomingSection(),
                        const SizedBox(height: 80), // FAB space
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar() {
    final greeting = _getGreeting();
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF2563EB),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userName ?? 'Utilisateur',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(_getRoleIcon(), color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              _getRoleText(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(DateTime.now()),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        // Bouton déconnexion rapide
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: 'Se déconnecter',
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Déconnexion'),
                content: const Text('Voulez-vous vraiment vous déconnecter ?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Déconnecter'),
                  ),
                ],
              ),
            );
            if (confirm == true && mounted) {
              await _authService.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              }
            }
          },
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () {
                if (widget.onNavigate != null) {
                  widget.onNavigate!(4);
                } else {
                  Navigator.pushNamed(context, '/notifications');
                }
              },
            ),
            if (_pendingCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_pendingCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.inventory_2_outlined,
            label: 'Ressources',
            value: '$_totalResources',
            color: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.hourglass_empty,
            label: 'En attente',
            value: '$_pendingCount',
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline,
            label: 'Confirmées',
            value: '$_confirmedCount',
            color: const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions rapides',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.search,
                label: 'Trouver une\nressource',
                color: const Color(0xFF2563EB),
                onTap: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(1);
                  } else {
                    Navigator.pushNamed(context, '/resources');
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.calendar_month,
                label: 'Voir le\ncalendrier',
                color: const Color(0xFF7C3AED),
                onTap: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(2);
                  } else {
                    Navigator.pushNamed(context, '/calendar');
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.bookmark,
                label: 'Mes\nréservations',
                color: const Color(0xFF059669),
                onTap: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(3);
                  } else {
                    Navigator.pushNamed(context, '/my_reservations');
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Prochaines réservations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                if (widget.onNavigate != null) {
                  widget.onNavigate!(3);
                } else {
                  Navigator.pushNamed(context, '/my_reservations');
                }
              },
              child: const Text('Voir tout'),
            ),          ],
        ),
        const SizedBox(height: 8),
        if (_upcomingReservations.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.event_available,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(
                  'Aucune réservation à venir',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    if (widget.onNavigate != null) {
                      widget.onNavigate!(1);
                    } else {
                      Navigator.pushNamed(context, '/resources');
                    }
                  },
                  child: const Text('Réserver maintenant'),
                ),
              ],
            ),
          )
        else
          ...(_upcomingReservations.map((r) => _UpcomingCard(data: r))),
      ],
    );
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour,';
    if (h < 18) return 'Bon après-midi,';
    return 'Bonsoir,';
  }

  IconData _getRoleIcon() {
    switch (_userRole) {
      case 'admin':
        return Icons.shield;
      case 'manager':
        return Icons.manage_accounts;
      default:
        return Icons.person;
    }
  }

  String _getRoleText() {
    switch (_userRole) {
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      default:
        return 'Utilisateur';
    }
  }
}

// ─── Composants internes ─────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _UpcomingCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final start = data['startTime'] as DateTime;
    final end = data['endTime'] as DateTime;
    final status = data['status'] as String;
    final isConfirmed = status == 'confirmed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfirmed
              ? const Color(0xFF10B981).withOpacity(0.3)
              : const Color(0xFFF59E0B).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: isConfirmed
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('d', 'fr_FR').format(start),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB)),
                ),
                Text(
                  DateFormat('MMM', 'fr_FR').format(start),
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['resourceName'] as String,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('HH:mm').format(start)} – ${DateFormat('HH:mm').format(end)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isConfirmed
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isConfirmed ? 'Confirmée' : 'En attente',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isConfirmed
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// update home UI

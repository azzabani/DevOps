// lib/views/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:flutter_booking/theme/app_theme.dart';
import 'package:flutter_booking/widgets/falling_resources_bg.dart';
import 'package:flutter_booking/widgets/app_logo.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  final void Function(int index)? onNavigate;
  const HomePage({super.key, this.onNavigate});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _userName;
  String? _userRole;
  int _pendingCount = 0;
  int _confirmedCount = 0;
  int _totalResources = 0;
  bool _isLoading = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _headerSlide;
  late Animation<double> _staggerAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _staggerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
            begin: const Offset(0, -0.2), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _slideController, curve: Curves.easeOutCubic));
    _staggerAnim =
        CurvedAnimation(parent: _staggerController, curve: Curves.easeOut);

    _loadAll();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadUserData(), _loadStats()]);
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeController.forward();
      _slideController.forward();
      Future.delayed(const Duration(milliseconds: 200),
          () => _staggerController.forward());
    }
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
      final results = await Future.wait([
        _firestore
            .collection('reservations')
            .where('userId', isEqualTo: user.uid)
            .get(),
        _firestore.collection('resources').get(),
      ]);
      int pending = 0, confirmed = 0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const FallingResourcesBg(count: 18, globalOpacity: 0.7),
          _isLoading
              ? _buildSkeleton()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    setState(() => _isLoading = true);
                    _fadeController.reset();
                    _slideController.reset();
                    _staggerController.reset();
                    await _loadAll();
                  },
                  child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        FadeTransition(
                          opacity: _staggerAnim,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatsRow(),
                              const SizedBox(height: 24),
                              _buildQuickActions(),
                              const SizedBox(height: 24),
                              _buildUpcomingSection(),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildSliverAppBar() {
    final greeting = _getGreeting();
    return SliverAppBar(
      expandedHeight: 170,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: SlideTransition(
          position: _headerSlide,
          child: Container(
            decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
            child: Stack(
              children: [
                // Cercle décoratif
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -20,
                  left: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                ),
                SafeArea(
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
                                Text(greeting,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.75),
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(
                                  _userName ?? 'Utilisateur',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            _RoleBadge(role: _userRole),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                              .format(DateTime.now()),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: _confirmLogout,
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
                      color: AppColors.error, shape: BoxShape.circle),
                  child: Text('$_pendingCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
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
          child: _AnimatedStatCard(
            icon: Icons.inventory_2_rounded,
            label: 'Ressources',
            value: '$_totalResources',
            color: AppColors.primary,
            delay: 0,
            controller: _staggerController,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AnimatedStatCard(
            icon: Icons.hourglass_top_rounded,
            label: 'En attente',
            value: '$_pendingCount',
            color: AppColors.warning,
            delay: 100,
            controller: _staggerController,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AnimatedStatCard(
            icon: Icons.check_circle_rounded,
            label: 'Confirmées',
            value: '$_confirmedCount',
            color: AppColors.success,
            delay: 200,
            controller: _staggerController,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Actions rapides',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AnimatedActionCard(
                icon: Icons.search_rounded,
                label: 'Trouver\nune ressource',
                gradient: AppColors.gradientPrimary,
                onTap: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(1);
                  } else {
                    Navigator.pushNamed(context, '/resources');
                  }
                },
                delay: 50,
                controller: _staggerController,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnimatedActionCard(
                icon: Icons.calendar_month_rounded,
                label: 'Voir le\ncalendrier',
                gradient: AppColors.gradientSecondary,
                onTap: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(2);
                  } else {
                    Navigator.pushNamed(context, '/calendar');
                  }
                },
                delay: 150,
                controller: _staggerController,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnimatedActionCard(
                icon: Icons.bookmark_rounded,
                label: 'Mes\nréservations',
                gradient: AppColors.gradientSuccess,
                onTap: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(3);
                  } else {
                    Navigator.pushNamed(context, '/my_reservations');
                  }
                },
                delay: 250,
                controller: _staggerController,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpcomingSection() {
    final user = _authService.currentUser;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Prochaines réservations',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            TextButton(
              onPressed: () {
                if (widget.onNavigate != null) {
                  widget.onNavigate!(3);
                } else {
                  Navigator.pushNamed(context, '/my_reservations');
                }
              },
              child: const Text('Voir tout',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (user == null)
          _EmptyUpcoming(onTap: () {
            if (widget.onNavigate != null) {
              widget.onNavigate!(1);
            } else {
              Navigator.pushNamed(context, '/resources');
            }
          })
        else
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('reservations')
                .where('userId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2)),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _EmptyUpcoming(onTap: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(1);
                  } else {
                    Navigator.pushNamed(context, '/resources');
                  }
                });
              }

              // Filtrer : status pending/confirmed ET startTime dans le futur
              final upcoming = snapshot.data!.docs
                  .where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final status = d['status'] as String? ?? '';
                    if (status != 'pending' && status != 'confirmed') {
                      return false;
                    }
                    final rawStart = d['startTime'];
                    if (rawStart is! Timestamp) return false;
                    return rawStart.toDate().isAfter(now);
                  })
                  .map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final start = (d['startTime'] as Timestamp).toDate();
                    final rawEnd = d['endTime'];
                    final end = rawEnd is Timestamp
                        ? rawEnd.toDate()
                        : start.add(const Duration(hours: 1));
                    final resourceName =
                        (d['resourceName'] as String?)?.isNotEmpty == true
                            ? d['resourceName'] as String
                            : 'Ressource';
                    return {
                      'id': doc.id,
                      'resourceName': resourceName,
                      'startTime': start,
                      'endTime': end,
                      'status': d['status'] as String,
                    };
                  })
                  .toList()
                ..sort((a, b) => (a['startTime'] as DateTime)
                    .compareTo(b['startTime'] as DateTime));

              final limited = upcoming.take(3).toList();

              if (limited.isEmpty) {
                return _EmptyUpcoming(onTap: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(1);
                  } else {
                    Navigator.pushNamed(context, '/resources');
                  }
                });
              }

              return Column(
                children: limited
                    .asMap()
                    .entries
                    .map((e) => _AnimatedUpcomingCard(
                          data: e.value,
                          index: e.key,
                          controller: _staggerController,
                        ))
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Déconnexion',
        message: 'Voulez-vous vraiment vous déconnecter ?',
        confirmLabel: 'Déconnecter',
        confirmColor: AppColors.error,
      ),
    );
    if (confirm == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    }
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour,';
    if (h < 18) return 'Bon après-midi,';
    return 'Bonsoir,';
  }
}

// ─── Widgets internes ─────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String? role;
  const _RoleBadge({this.role});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (role) {
      'admin' => (Icons.shield_rounded, 'Admin'),
      'manager' => (Icons.manage_accounts_rounded, 'Manager'),
      _ => (Icons.person_rounded, 'Utilisateur'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AnimatedStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final int delay;
  final AnimationController controller;

  const _AnimatedStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.delay,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final t = Curves.easeOutBack.transform(
          ((controller.value * 1000 - delay) / 600).clamp(0.0, 1.0),
        );
        return Transform.scale(
          scale: 0.8 + 0.2 * t,
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 16,
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
            Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: -0.5)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }
}

class _AnimatedActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final int delay;
  final AnimationController controller;

  const _AnimatedActionCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
    required this.delay,
    required this.controller,
  });

  @override
  State<_AnimatedActionCard> createState() => _AnimatedActionCardState();
}

class _AnimatedActionCardState extends State<_AnimatedActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _pressController, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, child) {
        final t = Curves.easeOutBack.transform(
          ((widget.controller.value * 1000 - widget.delay) / 600)
              .clamp(0.0, 1.0),
        );
        return Transform.translate(
          offset: Offset(0, 20 * (1 - t)),
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: widget.gradient.colors.first.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(widget.icon, color: Colors.white, size: 28),
                const SizedBox(height: 8),
                Text(widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedUpcomingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;
  final AnimationController controller;

  const _AnimatedUpcomingCard({
    required this.data,
    required this.index,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final start = data['startTime'] as DateTime;
    final end = data['endTime'] as DateTime;
    final status = data['status'] as String;
    final isConfirmed = status == 'confirmed';
    final statusColor = isConfirmed ? AppColors.success : AppColors.warning;

    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final delay = 300 + index * 100;
        final t = Curves.easeOutCubic.transform(
          ((controller.value * 1000 - delay) / 500).clamp(0.0, 1.0),
        );
        return Transform.translate(
          offset: Offset(30 * (1 - t), 0),
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 52,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(DateFormat('d', 'fr_FR').format(start),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  Text(DateFormat('MMM', 'fr_FR').format(start),
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['resourceName'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '${DateFormat('HH:mm').format(start)} – ${DateFormat('HH:mm').format(end)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isConfirmed ? 'Confirmée' : 'En attente',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyUpcoming extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyUpcoming({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available_rounded,
                size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          const Text('Aucune réservation à venir',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onTap,
            child: const Text('Réserver maintenant'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor, foregroundColor: Colors.white),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

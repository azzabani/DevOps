// lib/views/admin/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  int _totalReservations = 0;
  int _pendingCount = 0;
  int _confirmedCount = 0;
  int _cancelledCount = 0;
  int _rejectedCount = 0;
  int _totalResources = 0;
  int _totalUsers = 0;

  // Reservations des 7 derniers jours par jour
  Map<String, int> _weeklyStats = {};

  // Top ressources
  List<Map<String, dynamic>> _topResources = [];

  // Réservations récentes
  List<Map<String, dynamic>> _recentReservations = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadGlobalStats(),
      _loadWeeklyStats(),
      _loadTopResources(),
      _loadRecentReservations(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadGlobalStats() async {
    final results = await Future.wait([
      _firestore.collection('reservations').get(),
      _firestore.collection('resources').get(),
      _firestore.collection('users').get(),
    ]);

    int pending = 0, confirmed = 0, cancelled = 0, rejected = 0;
    for (final doc in results[0].docs) {
      final status = (doc.data() as Map<String, dynamic>)['status'] ?? '';
      if (status == 'pending') pending++;
      else if (status == 'confirmed') confirmed++;
      else if (status == 'cancelled') cancelled++;
      else if (status == 'rejected') rejected++;
    }

    if (mounted) {
      setState(() {
        _totalReservations = results[0].docs.length;
        _pendingCount = pending;
        _confirmedCount = confirmed;
        _cancelledCount = cancelled;
        _rejectedCount = rejected;
        _totalResources = results[1].docs.length;
        _totalUsers = results[2].docs.length;
      });
    }
  }

  Future<void> _loadWeeklyStats() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));

    final snap = await _firestore
        .collection('reservations')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
        .get();

    final Map<String, int> stats = {};
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = DateFormat('EEE', 'fr_FR').format(day);
      stats[key] = 0;
    }

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['createdAt'] != null) {
        final date = (data['createdAt'] as Timestamp).toDate();
        final key = DateFormat('EEE', 'fr_FR').format(date);
        if (stats.containsKey(key)) {
          stats[key] = (stats[key] ?? 0) + 1;
        }
      }
    }

    if (mounted) setState(() => _weeklyStats = stats);
  }

  Future<void> _loadTopResources() async {
    final snap = await _firestore
        .collection('reservations')
        .where('status', whereIn: ['confirmed', 'pending'])
        .get();

    final Map<String, int> counts = {};
    for (final doc in snap.docs) {
      final rid = (doc.data() as Map<String, dynamic>)['resourceId'] ?? '';
      if (rid.isNotEmpty) counts[rid] = (counts[rid] ?? 0) + 1;
    }

    // Sort
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = <Map<String, dynamic>>[];
    for (final e in sorted.take(5)) {
      final rDoc =
          await _firestore.collection('resources').doc(e.key).get();
      if (rDoc.exists) {
        top.add({
          'name': rDoc.data()?['name'] ?? 'Ressource',
          'category': rDoc.data()?['category'] ?? '',
          'count': e.value,
        });
      }
    }
    if (mounted) setState(() => _topResources = top);
  }

  Future<void> _loadRecentReservations() async {
    final snap = await _firestore
        .collection('reservations')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    final recent = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      String resourceName = 'Ressource';
      if ((data['resourceId'] as String? ?? '').isNotEmpty) {
        final rDoc = await _firestore
            .collection('resources')
            .doc(data['resourceId'])
            .get();
        if (rDoc.exists) resourceName = rDoc.data()?['name'] ?? 'Ressource';
      }
      recent.add({
        'id': doc.id,
        'resourceName': resourceName,
        'userName': data['userName'] ?? 'Utilisateur',
        'status': data['status'] ?? 'pending',
        'startTime': data['startTime'] != null
            ? (data['startTime'] as Timestamp).toDate()
            : DateTime.now(),
        'createdAt': data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      });
    }
    if (mounted) setState(() => _recentReservations = recent);
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadDashboard,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Vue d\'ensemble'),
                  const SizedBox(height: 12),
                  _buildOverviewGrid(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Réservations – 7 derniers jours'),
                  const SizedBox(height: 12),
                  _buildWeeklyChart(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Statuts des réservations'),
                  const SizedBox(height: 12),
                  _buildStatusChart(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Ressources les plus demandées'),
                  const SizedBox(height: 12),
                  _buildTopResources(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Réservations récentes'),
                  const SizedBox(height: 12),
                  _buildRecentList(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildOverviewGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 0.85,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _StatTile('Total\nRéservations', '$_totalReservations',
            Icons.event_note, const Color(0xFF2563EB)),
        _StatTile('En\nAttente', '$_pendingCount', Icons.hourglass_empty,
            const Color(0xFFF59E0B)),
        _StatTile('Confirmées', '$_confirmedCount', Icons.check_circle,
            const Color(0xFF10B981)),
        _StatTile('Annulées', '$_cancelledCount', Icons.cancel,
            const Color(0xFFEF4444)),
        _StatTile('Rejetées', '$_rejectedCount', Icons.block,
            const Color(0xFFDC2626)),
        _StatTile('Ressources', '$_totalResources', Icons.inventory_2,
            const Color(0xFF7C3AED)),
        _StatTile('Utilisateurs', '$_totalUsers', Icons.people,
            const Color(0xFF0891B2)),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    if (_weeklyStats.isEmpty) {
      return const SizedBox(height: 80, child: Center(child: Text('Chargement...')));
    }
    final maxVal =
        _weeklyStats.values.fold(0, (a, b) => a > b ? a : b).toDouble();
    final safeMax = maxVal == 0 ? 1.0 : maxVal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weeklyStats.entries.map((e) {
                final ratio = e.value / safeMax;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (e.value > 0)
                          Text('${e.value}',
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          height: 80 * ratio + (e.value > 0 ? 4 : 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(
                                0.3 + 0.7 * ratio),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _weeklyStats.keys.map((k) {
              return Expanded(
                child: Text(k,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChart() {
    final total = _totalReservations == 0 ? 1 : _totalReservations;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          _StatusBar('En attente', _pendingCount, total,
              const Color(0xFFF59E0B)),
          const SizedBox(height: 10),
          _StatusBar('Confirmées', _confirmedCount, total,
              const Color(0xFF10B981)),
          const SizedBox(height: 10),
          _StatusBar('Annulées', _cancelledCount, total,
              const Color(0xFFEF4444)),
          const SizedBox(height: 10),
          _StatusBar('Rejetées', _rejectedCount, total,
              const Color(0xFFDC2626)),
        ],
      ),
    );
  }

  Widget _buildTopResources() {
    if (_topResources.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('Aucune donnée')),
      );
    }
    final maxCount =
        _topResources.fold(0, (a, b) => a > b['count'] ? a : b['count'] as int);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: _topResources.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final ratio = (r['count'] as int) / (maxCount == 0 ? 1 : maxCount);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _rankColor(i).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: _rankColor(i),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['name'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: Colors.grey.shade100,
                        color: _rankColor(i),
                        borderRadius: BorderRadius.circular(10),
                        minHeight: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('${r['count']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentList() {
    if (_recentReservations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('Aucune réservation récente')),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentReservations.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (ctx, i) {
          final r = _recentReservations[i];
          final status = r['status'] as String;
          final statusColor = status == 'confirmed'
              ? const Color(0xFF10B981)
              : status == 'pending'
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFEF4444);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.1),
              child: Text(
                (r['userName'] as String).substring(0, 1).toUpperCase(),
                style:
                    TextStyle(color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(r['resourceName'] as String,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              '${r['userName']} • ${DateFormat('dd/MM HH:mm').format(r['startTime'] as DateTime)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _rankColor(int index) {
    const colors = [
      Color(0xFFF59E0B),
      Color(0xFF94A3B8),
      Color(0xFFCD7C2F),
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
    ];
    return colors[index % colors.length];
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'confirmed':
        return 'Confirmée';
      case 'pending':
        return 'En attente';
      case 'cancelled':
        return 'Annulée';
      case 'rejected':
        return 'Rejetée';
      default:
        return s;
    }
  }
}

// ─── Sous-widgets ────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  height: 1.2)),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _StatusBar(this.label, this.count, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final ratio = count / total;
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.grey.shade100,
            color: color,
            borderRadius: BorderRadius.circular(10),
            minHeight: 8,
          ),
        ),
        const SizedBox(width: 8),
        Text('$count',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      ],
    );
  }
}
// update

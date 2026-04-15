// lib/views/admin/admin_validate_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_booking/models/reservation_model.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:flutter_booking/services/reservation_service.dart';
import 'package:flutter_booking/services/notification_service.dart';

class AdminValidatePage extends StatefulWidget {
  const AdminValidatePage({super.key});

  @override
  State<AdminValidatePage> createState() => _AdminValidatePageState();
}

class _AdminValidatePageState extends State<AdminValidatePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ReservationService _reservationService = ReservationService();
  final NotificationService _notifService = NotificationService();
  final AuthService _authService = AuthService();

  String _selectedTab = 'pending';
  bool _isProcessing = false;

  Future<void> _updateStatus(
      ReservationModel reservation, String newStatus) async {
    if (_isProcessing) return;

    String? motif;

    if (newStatus == 'rejected') {
      // Demander le motif de refus
      final motifCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rejeter la réservation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Voulez-vous rejeter la réservation de ${reservation.userName} ?'),
              const SizedBox(height: 12),
              TextField(
                controller: motifCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Motif du refus (optionnel)',
                  hintText: 'Ex: Ressource indisponible pour maintenance…',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Rejeter'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      motif = motifCtrl.text.trim();
    } else {
      // Confirmation simple pour la validation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmer la réservation'),
          content: Text(
              'Voulez-vous confirmer la réservation de ${reservation.userName} ?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Non')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isProcessing = true);

    try {
      // Nom de la ressource
      String resourceName = 'Ressource';
      if (reservation.resourceId.isNotEmpty) {
        final doc = await _firestore
            .collection('resources')
            .doc(reservation.resourceId)
            .get();
        if (doc.exists) {
          resourceName =
              (doc.data() as Map<String, dynamic>)['name'] ?? 'Ressource';
        }
      }

      // Nom du validateur (admin/manager courant)
      final currentUser = _authService.currentUser;
      String validatorName = 'Admin';
      if (currentUser != null) {
        final vDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (vDoc.exists) {
          validatorName =
              (vDoc.data() as Map<String, dynamic>)['name'] ?? 'Admin';
        }
      }

      final dateStr = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR')
          .format(reservation.startTime);

      // ✅ Mise à jour Firestore avec validatedBy
      await _firestore
          .collection('reservations')
          .doc(reservation.id)
          .update({
        'status': newStatus,
        'validatedAt': FieldValue.serverTimestamp(),
        'validatedBy': validatorName,
      });

      // 🔔 Notifier l'utilisateur
      await _notifService.createNotification(
        userId: reservation.userId,
        title: newStatus == 'confirmed'
            ? '✅ Réservation confirmée !'
            : '❌ Réservation rejetée',
        message: newStatus == 'confirmed'
            ? 'Votre réservation pour "$resourceName" le $dateStr a été confirmée par $validatorName.'
            : 'Votre réservation pour "$resourceName" le $dateStr a été rejetée par $validatorName.'
              '${motif != null && motif.isNotEmpty ? ' Motif : $motif' : ''}',
        type: newStatus == 'confirmed' ? 'confirmation' : 'rejection',
        reservationId: reservation.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newStatus == 'confirmed'
              ? '✅ Réservation confirmée'
              : '❌ Réservation rejetée'),
          backgroundColor:
              newStatus == 'confirmed' ? Colors.green : Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabBar(),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTab('En attente', 'pending', Colors.orange),
            const SizedBox(width: 8),
            _buildTab('Confirmées', 'confirmed', Colors.green),
            const SizedBox(width: 8),
            _buildTab('Rejetées', 'rejected', Colors.red),
            const SizedBox(width: 8),
            _buildTab('Toutes', 'all', Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, String value, Color color) {
    final isSelected = _selectedTab == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final statusFilter =
        _selectedTab == 'all' ? null : _selectedTab;

    return StreamBuilder<List<ReservationModel>>(
      stream: _reservationService.getAllReservations(
          statusFilter: statusFilter),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Erreur de chargement\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reservations = snapshot.data ?? [];
        if (reservations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 72, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  _selectedTab == 'pending'
                      ? 'Aucune réservation en attente'
                      : _selectedTab == 'confirmed'
                          ? 'Aucune réservation confirmée'
                          : _selectedTab == 'rejected'
                              ? 'Aucune réservation rejetée'
                              : 'Aucune réservation',
                  style: TextStyle(
                      fontSize: 15, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reservations.length,
          itemBuilder: (context, i) =>
              _buildCard(reservations[i]),
        );
      },
    );
  }

  Widget _buildCard(ReservationModel reservation) {
    final status = reservation.status;
    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          // Barre de couleur haut
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Utilisateur + statut
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.15),
                      radius: 20,
                      child: Text(
                        reservation.userName.isNotEmpty
                            ? reservation.userName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reservation.userName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          _ResourceNameWidget(
                              resourceId: reservation.resourceId),
                        ],
                      ),
                    ),
                    _StatusBadge(status: status),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Date + heure
                Row(children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                        .format(reservation.startTime),
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade700),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.access_time_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('HH:mm').format(reservation.startTime)} → ${DateFormat('HH:mm').format(reservation.endTime)}',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade700),
                  ),
                ]),

                // Notes
                if (reservation.notes != null &&
                    reservation.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes_outlined,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(reservation.notes!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600))),
                    ],
                  ),
                ],

                // Validé par
                if (reservation.validatedAt != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.verified_user_outlined,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text(
                      'Traité le ${DateFormat('dd/MM/yyyy HH:mm').format(reservation.validatedAt!)}'
                      '${reservation.validatedBy != null ? ' par ${reservation.validatedBy}' : ''}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ]),
                ],

                // Créée le
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Créée le ${DateFormat('dd/MM/yyyy HH:mm').format(reservation.createdAt)}',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade400),
                  ),
                ),

                // Boutons Confirmer / Rejeter (seulement si pending)
                if (status == 'pending') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () => _updateStatus(
                                  reservation, 'confirmed'),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Confirmer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () => _updateStatus(
                                  reservation, 'rejected'),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Rejeter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}

// ── Widgets helper ────────────────────────────────────────────────────────────

class _ResourceNameWidget extends StatelessWidget {
  final String resourceId;
  const _ResourceNameWidget({required this.resourceId});

  @override
  Widget build(BuildContext context) {
    if (resourceId.isEmpty) {
      return Text('Ressource inconnue',
          style:
              TextStyle(fontSize: 12, color: Colors.grey.shade500));
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('resources')
          .doc(resourceId)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Text('…',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade400));
        }
        if (!snap.data!.exists) {
          return Text('Ressource supprimée',
              style: TextStyle(
                  fontSize: 12, color: Colors.orange.shade400));
        }
        final name = (snap.data!.data()
                as Map<String, dynamic>)['name'] ??
            'Ressource';
        return Text(name,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade600));
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'confirmed' => ('Confirmée', Colors.green),
      'rejected' => ('Rejetée', Colors.red),
      'cancelled' => ('Annulée', Colors.grey),
      _ => ('En attente', Colors.orange),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

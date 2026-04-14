// lib/views/calendar/my_reservations_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_booking/models/reservation_model.dart';
import 'package:flutter_booking/models/resource_model.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:flutter_booking/services/reservation_service.dart';
import 'package:flutter_booking/services/notification_service.dart';
import 'package:flutter_booking/services/pdf_service.dart';
import 'package:flutter_booking/services/ical_service.dart';

class MyReservationsPage extends StatefulWidget {
  const MyReservationsPage({super.key});

  @override
  State<MyReservationsPage> createState() => _MyReservationsPageState();
}

class _MyReservationsPageState extends State<MyReservationsPage> {
  final AuthService _authService = AuthService();
  final ReservationService _reservationService = ReservationService();
  final NotificationService _notifService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _filter = 'all'; // all | pending | confirmed | cancelled

  Future<void> _cancelReservation(ReservationModel reservation,
      String resourceName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la réservation'),
        content: Text(
            'Voulez-vous vraiment annuler la réservation de "$resourceName" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Annuler la réservation',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _firestore
        .collection('reservations')
        .doc(reservation.id)
        .update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final user = _authService.currentUser;
    if (user != null) {
      // Notifier l'utilisateur
      await _notifService.createNotification(
        userId: user.uid,
        title: '❌ Réservation annulée',
        message:
            '"$resourceName" – ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(reservation.startTime)}',
        type: 'cancellation',
        reservationId: reservation.id,
      );

      // Notifier les admins/managers
      final admins = await _firestore
          .collection('users')
          .where('role', whereIn: ['admin', 'manager']).get();
      for (final admin in admins.docs) {
        if (admin.id == user.uid) continue;
        await _notifService.createNotification(
          userId: admin.id,
          title: '🚫 Réservation annulée',
          message:
              '${reservation.userName} a annulé "$resourceName" – ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(reservation.startTime)}',
          type: 'cancellation',
          reservationId: reservation.id,
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Réservation annulée'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes réservations'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: Column(
        children: [
          // ── Filtres ─────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                      label: 'Toutes',
                      value: 'all',
                      current: _filter,
                      color: Colors.blue,
                      onTap: () => setState(() => _filter = 'all')),
                  const SizedBox(width: 8),
                  _FilterChip(
                      label: 'En attente',
                      value: 'pending',
                      current: _filter,
                      color: Colors.orange,
                      onTap: () => setState(() => _filter = 'pending')),
                  const SizedBox(width: 8),
                  _FilterChip(
                      label: 'Confirmées',
                      value: 'confirmed',
                      current: _filter,
                      color: Colors.green,
                      onTap: () =>
                          setState(() => _filter = 'confirmed')),
                  const SizedBox(width: 8),
                  _FilterChip(
                      label: 'Annulées/Rejetées',
                      value: 'cancelled',
                      current: _filter,
                      color: Colors.red,
                      onTap: () =>
                          setState(() => _filter = 'cancelled')),
                ],
              ),
            ),
          ),

          // ── Liste ────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<ReservationModel>>(
              stream: _reservationService.getUserReservations(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                var reservations = snapshot.data ?? [];

                // Appliquer le filtre
                if (_filter != 'all') {
                  if (_filter == 'cancelled') {
                    reservations = reservations
                        .where((r) =>
                            r.status == 'cancelled' ||
                            r.status == 'rejected')
                        .toList();
                  } else {
                    reservations = reservations
                        .where((r) => r.status == _filter)
                        .toList();
                  }
                }

                if (reservations.isEmpty) {
                  return _EmptyState(filter: _filter);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: reservations.length,
                  itemBuilder: (context, i) {
                    final res = reservations[i];
                    return _ReservationCard(
                      reservation: res,
                      onCancel: (resourceName) =>
                          _cancelReservation(res, resourceName),
                      onEdit: () {
                        Navigator.pushNamed(
                          context,
                          '/edit_reservation',
                          arguments: res,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte réservation ────────────────────────────────────────────────────────

class _ReservationCard extends StatelessWidget {
  final ReservationModel reservation;
  final void Function(String resourceName) onCancel;
  final VoidCallback onEdit;

  const _ReservationCard({
    required this.reservation,
    required this.onCancel,
    required this.onEdit,
  });

  Color get _statusColor {
    switch (reservation.status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (reservation.status) {
      case 'confirmed':
        return '✅ Confirmée';
      case 'pending':
        return '⏳ En attente de validation';
      case 'rejected':
        return '❌ Rejetée';
      case 'cancelled':
        return '🚫 Annulée';
      default:
        return reservation.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return FutureBuilder<DocumentSnapshot>(
      future:
          firestore.collection('resources').doc(reservation.resourceId).get(),
      builder: (context, snap) {
        final resourceName = snap.hasData && snap.data!.exists
            ? (snap.data!.data() as Map<String, dynamic>)['name'] ??
                'Ressource'
            : reservation.resourceId.isNotEmpty
                ? 'Ressource'
                : 'Ressource supprimée';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              // Barre de statut colorée
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre + statut
                    Row(
                      children: [
                        Expanded(
                          child: Text(resourceName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_statusLabel,
                              style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Date & heure
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                              .format(reservation.startTime),
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('HH:mm').format(reservation.startTime)} → '
                          '${DateFormat('HH:mm').format(reservation.endTime)}',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700),
                        ),
                      ],
                    ),

                    // Notes
                    if (reservation.notes != null &&
                        reservation.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(reservation.notes!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600)),
                          ),
                        ],
                      ),
                    ],

                    // Validé par
                    if (reservation.validatedAt != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.verified_user,
                              size: 14, color: Colors.green.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'Validée le ${DateFormat('dd/MM/yyyy HH:mm').format(reservation.validatedAt!)}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade600),
                          ),
                        ],
                      ),
                    ],

                    // Boutons PDF / iCal (uniquement si confirmée)
                    if (reservation.status == 'confirmed') ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _generatePdf(context, resourceName),
                              icon: const Icon(Icons.picture_as_pdf, size: 16),
                              label: const Text('PDF'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.shade300),
                                foregroundColor: Colors.red,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _exportIcal(context),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: const Text('iCal'),
                              style: OutlinedButton.styleFrom(
                                side:
                                    BorderSide(color: Colors.purple.shade300),
                                foregroundColor: Colors.purple,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Actions (uniquement si pending)
                    if (reservation.status == 'pending') ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Modifier'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: Colors.blue.shade300),
                                foregroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => onCancel(resourceName),
                              icon: const Icon(Icons.cancel_outlined,
                                  size: 16),
                              label: const Text('Annuler'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: Colors.red.shade300),
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
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
      },
    );
  }
  Future<void> _generatePdf(BuildContext context, String resourceName) async {
    try {
      final resourceDoc = await FirebaseFirestore.instance
          .collection('resources')
          .doc(reservation.resourceId)
          .get();

      final resource = resourceDoc.exists
          ? ResourceModel.fromFirestore(
              resourceDoc.data() as Map<String, dynamic>, resourceDoc.id)
          : ResourceModel(
              id: reservation.resourceId,
              name: resourceName,
              description: '',
              image: '',
              capacity: 0,
              category: '',
            );

      final pdfBytes = await PdfService()
          .generateConfirmationPdf(reservation, resource);
      await PdfService()
          .sharePdf(pdfBytes, 'reservation_${reservation.id}.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur PDF: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportIcal(BuildContext context) async {
    try {
      await ICalService().shareIcs(reservation);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur iCal: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            )),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final messages = {
      'all': 'Aucune réservation pour l\'instant',
      'pending': 'Aucune réservation en attente',
      'confirmed': 'Aucune réservation confirmée',
      'cancelled': 'Aucune réservation annulée ou rejetée',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            messages[filter] ?? 'Aucune réservation',
            style: TextStyle(
                fontSize: 15, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

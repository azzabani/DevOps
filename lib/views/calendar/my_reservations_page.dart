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
import 'package:flutter_booking/theme/app_theme.dart';
import 'package:flutter_booking/widgets/falling_resources_bg.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes réservations'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
        ),
      ),
      body: Stack(
        children: [
          const FallingResourcesBg(count: 16, globalOpacity: 0.65),
          Column(
        children: [
          // ── Filtres ─────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                      label: 'Toutes',
                      value: 'all',
                      current: _filter,
                      color: AppColors.primary,
                      onTap: () => setState(() => _filter = 'all')),
                  const SizedBox(width: 8),
                  _FilterChip(
                      label: 'En attente',
                      value: 'pending',
                      current: _filter,
                      color: AppColors.warning,
                      onTap: () => setState(() => _filter = 'pending')),
                  const SizedBox(width: 8),
                  _FilterChip(
                      label: 'Confirmées',
                      value: 'confirmed',
                      current: _filter,
                      color: AppColors.success,
                      onTap: () => setState(() => _filter = 'confirmed')),
                  const SizedBox(width: 8),
                  _FilterChip(
                      label: 'Annulées',
                      value: 'cancelled',
                      current: _filter,
                      color: AppColors.error,
                      onTap: () => setState(() => _filter = 'cancelled')),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Liste ────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<ReservationModel>>(
              stream: _reservationService.getUserReservations(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Erreur: ${snapshot.error}',
                          style: const TextStyle(
                              color: AppColors.textSecondary)));
                }

                var reservations = snapshot.data ?? [];
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: reservations.length,
                  itemBuilder: (context, i) {
                    final res = reservations[i];
                    return _AnimatedReservationCard(
                      reservation: res,
                      index: i,
                      onCancel: (resourceName) =>
                          _cancelReservation(res, resourceName),
                      onEdit: () => Navigator.pushNamed(
                          context, '/edit_reservation',
                          arguments: res),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }
}

// ── Carte réservation animée ─────────────────────────────────────────────────

class _AnimatedReservationCard extends StatefulWidget {
  final ReservationModel reservation;
  final int index;
  final void Function(String resourceName) onCancel;
  final VoidCallback onEdit;

  const _AnimatedReservationCard({
    required this.reservation,
    required this.index,
    required this.onCancel,
    required this.onEdit,
  });

  @override
  State<_AnimatedReservationCard> createState() =>
      _AnimatedReservationCardState();
}

class _AnimatedReservationCardState extends State<_AnimatedReservationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + widget.index * 60));
    _fadeAnim =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 60),
        () => _controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.reservation.status) {
      case 'confirmed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  String get _statusLabel {
    switch (widget.reservation.status) {
      case 'confirmed':
        return 'Confirmée';
      case 'pending':
        return 'En attente';
      case 'rejected':
        return 'Rejetée';
      case 'cancelled':
        return 'Annulée';
      default:
        return widget.reservation.status;
    }
  }

  IconData get _statusIcon {
    switch (widget.reservation.status) {
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'cancelled':
        return Icons.event_busy_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: FutureBuilder<DocumentSnapshot>(
          future: firestore
              .collection('resources')
              .doc(widget.reservation.resourceId)
              .get(),
          builder: (context, snap) {
            final resourceName = snap.hasData && snap.data!.exists
                ? (snap.data!.data() as Map<String, dynamic>)['name'] ??
                    'Ressource'
                : 'Ressource';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: _statusColor.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Barre de statut
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
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
                                      fontSize: 16,
                                      color: AppColors.textPrimary)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon,
                                      size: 12, color: _statusColor),
                                  const SizedBox(width: 4),
                                  Text(_statusLabel,
                                      style: TextStyle(
                                          color: _statusColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Date
                        _InfoRow(
                          icon: Icons.calendar_today_rounded,
                          text: DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                              .format(widget.reservation.startTime),
                        ),
                        const SizedBox(height: 6),
                        _InfoRow(
                          icon: Icons.access_time_rounded,
                          text:
                              '${DateFormat('HH:mm').format(widget.reservation.startTime)} → ${DateFormat('HH:mm').format(widget.reservation.endTime)}',
                        ),
                        if (widget.reservation.notes != null &&
                            widget.reservation.notes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _InfoRow(
                            icon: Icons.notes_rounded,
                            text: widget.reservation.notes!,
                          ),
                        ],
                        if (widget.reservation.validatedAt != null) ...[
                          const SizedBox(height: 6),
                          _InfoRow(
                            icon: Icons.verified_user_rounded,
                            text:
                                'Validée le ${DateFormat('dd/MM/yyyy HH:mm').format(widget.reservation.validatedAt!)}',
                            color: AppColors.success,
                          ),
                        ],
                        // Actions
                        if (widget.reservation.status == 'confirmed' ||
                            widget.reservation.status == 'pending') ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          _buildActions(resourceName),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActions(String resourceName) {
    if (widget.reservation.status == 'confirmed') {
      return Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.picture_as_pdf_rounded,
              label: 'PDF',
              color: AppColors.error,
              onTap: () => _generatePdf(context, resourceName),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: Icons.calendar_today_rounded,
              label: 'iCal',
              color: AppColors.secondary,
              onTap: () => _exportIcal(context),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.edit_rounded,
            label: 'Modifier',
            color: AppColors.primary,
            onTap: widget.onEdit,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.cancel_outlined,
            label: 'Annuler',
            color: AppColors.error,
            onTap: () => widget.onCancel(resourceName),
          ),
        ),
      ],
    );
  }

  Future<void> _generatePdf(BuildContext context, String resourceName) async {
    try {
      final resourceDoc = await FirebaseFirestore.instance
          .collection('resources')
          .doc(widget.reservation.resourceId)
          .get();
      final resource = resourceDoc.exists
          ? ResourceModel.fromFirestore(
              resourceDoc.data() as Map<String, dynamic>, resourceDoc.id)
          : ResourceModel(
              id: widget.reservation.resourceId,
              name: resourceName,
              description: '',
              image: '',
              capacity: 0,
              category: '',
            );
      final pdfBytes =
          await PdfService().generateConfirmationPdf(widget.reservation, resource);
      await PdfService()
          .sharePdf(pdfBytes, 'reservation_${widget.reservation.id}.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur PDF: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _exportIcal(BuildContext context) async {
    try {
      await ICalService().shareIcs(widget.reservation);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur iCal: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: c, height: 1.4)),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              )),
        ),
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
      'cancelled': 'Aucune réservation annulée',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available_rounded,
                size: 48, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          Text(
            messages[filter] ?? 'Aucune réservation',
            style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

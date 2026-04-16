// lib/views/calendar/booking_page.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_booking/models/resource_model.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:flutter_booking/services/notification_service.dart';

class BookingPage extends StatefulWidget {
  final ResourceModel resource;
  const BookingPage({super.key, required this.resource});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notifService = NotificationService();

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  Map<DateTime, List<Map<String, dynamic>>> _bookedSlots = {};

  final List<TimeOfDay> _timeSlots = [
    for (int h = 8; h <= 17; h++) TimeOfDay(hour: h, minute: 0),
  ];

  @override
  void initState() {
    super.initState();
    _loadBookedSlots();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadBookedSlots() async {
    final snap = await _firestore
        .collection('reservations')
        .where('resourceId', isEqualTo: widget.resource.id)
        .where('status', whereIn: ['pending', 'confirmed']).get();

    final Map<DateTime, List<Map<String, dynamic>>> slots = {};
    for (final doc in snap.docs) {
      final d = doc.data();
      final start = (d['startTime'] as Timestamp).toDate();
      final key = DateTime(start.year, start.month, start.day);
      slots.putIfAbsent(key, () => []).add({
        'start': start,
        'end': (d['endTime'] as Timestamp).toDate(),
      });
    }
    if (mounted) setState(() => _bookedSlots = slots);
  }

  bool _isSlotAvailable(TimeOfDay time) {
    final key = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    if (!_bookedSlots.containsKey(key)) return true;
    final slotStart = DateTime(
        _selectedDay.year, _selectedDay.month, _selectedDay.day, time.hour, time.minute);
    final slotEnd = slotStart.add(const Duration(hours: 1));
    for (final b in _bookedSlots[key]!) {
      if (slotStart.isBefore(b['end']) && slotEnd.isAfter(b['start'])) return false;
    }
    return true;
  }

  Future<void> _createReservation() async {
    if (_selectedStartTime == null || _selectedEndTime == null) {
      _showSnack('Veuillez sélectionner un créneau horaire', isError: true);
      return;
    }

    final user = _authService.currentUser;
    if (user == null) return;

    final startDT = DateTime(_selectedDay.year, _selectedDay.month,
        _selectedDay.day, _selectedStartTime!.hour, _selectedStartTime!.minute);
    final endDT = DateTime(_selectedDay.year, _selectedDay.month,
        _selectedDay.day, _selectedEndTime!.hour, _selectedEndTime!.minute);

    if (!endDT.isAfter(startDT)) {
      _showSnack("L'heure de fin doit être après l'heure de début", isError: true);
      return;
    }

    // Vérification finale du créneau
    if (!_isSlotAvailable(_selectedStartTime!)) {
      _showSnack('Ce créneau n\'est plus disponible', isError: true);
      await _loadBookedSlots();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Récupérer le nom de l'utilisateur
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ??
          user.email?.split('@').first ??
          'Utilisateur';

      final dateStr =
          DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(startDT);

      // ✅ Créer la réservation dans Firestore (statut : pending)
      final reservationRef =
          await _firestore.collection('reservations').add({
        'resourceId': widget.resource.id,
        'userId': user.uid,
        'userName': userName,
        'startTime': Timestamp.fromDate(startDT),
        'endTime': Timestamp.fromDate(endDT),
        'status': 'pending', // toujours pending → doit être validé
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'resourceName': widget.resource.name, // dénormalisé pour affichage rapide
      });

      // 🔔 Notifier l'utilisateur
      await _notifService.createNotification(
        userId: user.uid,
        title: '📅 Réservation en attente',
        message:
            'Votre réservation pour "${widget.resource.name}" le $dateStr est en attente de validation.',
        type: 'reservation',
        reservationId: reservationRef.id,
      );

      // 🔔 Notifier tous les admins ET managers
      final adminManagerSnap = await _firestore
          .collection('users')
          .where('role', whereIn: ['admin', 'manager']).get();

      for (final adminDoc in adminManagerSnap.docs) {
        if (adminDoc.id == user.uid) continue; // ne pas notifier soi-même
        await _notifService.createNotification(
          userId: adminDoc.id,
          title: '🆕 Nouvelle réservation à valider',
          message:
              '$userName souhaite réserver "${widget.resource.name}" le $dateStr',
          type: 'validation',
          reservationId: reservationRef.id,
        );
      }

      if (mounted) {
        _showSnack('Réservation créée ! En attente de validation.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Réserver ${widget.resource.name}'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info ressource ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF2563EB).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2,
                            color: Color(0xFF2563EB)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.resource.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(
                                '${widget.resource.capacityLabel} · ${widget.resource.category}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Bandeau validation obligatoire ──────────────────
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Toute réservation nécessite une validation par un manager ou administrateur.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Calendrier ──────────────────────────────────────
                  const Text('Choisir la date',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10)
                      ],
                    ),
                    child: TableCalendar(
                      locale: 'fr_FR',
                      firstDay: DateTime.now(),
                      lastDay:
                          DateTime.now().add(const Duration(days: 60)),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (d) =>
                          isSameDay(d, _selectedDay),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                          _selectedStartTime = null;
                          _selectedEndTime = null;
                        });
                      },
                      calendarStyle: CalendarStyle(
                        selectedDecoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle),
                        todayDecoration: BoxDecoration(
                            color: const Color(0xFF2563EB)
                                .withOpacity(0.3),
                            shape: BoxShape.circle),
                      ),
                      headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Grille créneaux début ───────────────────────────
                  const Text('Heure de début',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _timeSlots.map((t) {
                      final available = _isSlotAvailable(t);
                      final selected = _selectedStartTime == t;
                      return _TimeChip(
                        time: t.format(context),
                        available: available,
                        selected: selected,
                        selectedColor: const Color(0xFF2563EB),
                        onTap: available
                            ? () => setState(() {
                                  _selectedStartTime = t;
                                  _selectedEndTime = null;
                                })
                            : null,
                      );
                    }).toList(),
                  ),

                  if (_selectedStartTime != null) ...[
                    const SizedBox(height: 20),
                    const Text('Heure de fin',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _timeSlots
                          .where((t) =>
                              t.hour > _selectedStartTime!.hour ||
                              (t.hour == _selectedStartTime!.hour &&
                                  t.minute >
                                      _selectedStartTime!.minute))
                          .map((t) {
                        final available = _isSlotAvailable(t);
                        final selected = _selectedEndTime == t;
                        return _TimeChip(
                          time: t.format(context),
                          available: available,
                          selected: selected,
                          selectedColor: const Color(0xFF10B981),
                          onTap: available
                              ? () =>
                                  setState(() => _selectedEndTime = t)
                              : null,
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Résumé créneau ──────────────────────────────────
                  if (_selectedStartTime != null &&
                      _selectedEndTime != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green),
                          const SizedBox(width: 10),
                          Text(
                            '${DateFormat('EEE d MMM', 'fr_FR').format(_selectedDay)}  ·  '
                            '${_selectedStartTime!.format(context)} → ${_selectedEndTime!.format(context)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ── Notes ───────────────────────────────────────────
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Notes (optionnel)',
                      hintText: 'Raison, commentaire…',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Bouton confirmer ────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: (_selectedStartTime != null &&
                              _selectedEndTime != null)
                          ? _createReservation
                          : null,
                      icon: const Icon(Icons.send),
                      label: const Text(
                        'Envoyer la demande de réservation',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String time;
  final bool available;
  final bool selected;
  final Color selectedColor;
  final VoidCallback? onTap;

  const _TimeChip({
    required this.time,
    required this.available,
    required this.selected,
    required this.selectedColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor
              : available
                  ? Colors.white
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? selectedColor
                : available
                    ? Colors.grey.shade300
                    : Colors.grey.shade200,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: selectedColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!available)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.block,
                    size: 12, color: Colors.grey.shade400),
              ),
            Text(
              time,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : available
                        ? Colors.black87
                        : Colors.grey.shade400,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// update calendar UI

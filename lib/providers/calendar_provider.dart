import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reservation_model.dart';

class CalendarProvider extends ChangeNotifier {
  DateTime _selectedDay = DateTime.now();
  String? _currentResourceId;
  List<ReservationModel> _resourceReservations = [];
  StreamSubscription<QuerySnapshot>? _subscription;

  DateTime get selectedDay => _selectedDay;
  String? get currentResourceId => _currentResourceId;

  List<ReservationModel> get activeReservations =>
      _resourceReservations.where((r) => r.isActive).toList();

  // Kept for backward compatibility
  DateTime get selectedDate => _selectedDay;

  void changeDate(DateTime date) {
    _selectedDay = date;
    notifyListeners();
  }

  void selectDay(DateTime day) {
    _selectedDay = day;
    notifyListeners();
  }

  Future<void> loadResourceReservations(String resourceId) async {
    await _subscription?.cancel();
    _currentResourceId = resourceId;
    _resourceReservations = [];
    notifyListeners();

    _subscription = FirebaseFirestore.instance
        .collection('reservations')
        .where('resourceId', isEqualTo: resourceId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .snapshots()
        .listen((snapshot) {
          _resourceReservations = snapshot.docs
              .map((doc) => ReservationModel.fromFirestore(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ))
              .toList();
          notifyListeners();
        });
  }

  List<int> getOccupiedHours(DateTime day) {
    final hours = <int>[];
    for (final r in activeReservations) {
      final sameDay = r.startTime.year == day.year &&
          r.startTime.month == day.month &&
          r.startTime.day == day.day;
      if (sameDay) {
        for (int h = r.startTime.hour; h < r.endTime.hour; h++) {
          hours.add(h);
        }
      }
    }
    return hours;
  }

  bool isSlotAvailable(DateTime start, DateTime end) {
    for (final r in activeReservations) {
      if (start.isBefore(r.endTime) && end.isAfter(r.startTime)) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

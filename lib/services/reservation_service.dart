// lib/services/reservation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_booking/models/resource_model.dart';
import 'package:flutter_booking/models/reservation_model.dart';

class ReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Ressources ───────────────────────────────────────────────────────────

  Stream<List<ResourceModel>> getResources() {
    return _firestore.collection('resources').snapshots().map(
          (snapshot) => snapshot.docs.map(_docToResource).toList(),
        );
  }

  Stream<List<ResourceModel>> getResourcesByCategory(String category) {
    return _firestore
        .collection('resources')
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_docToResource).toList());
  }

  ResourceModel _docToResource(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ResourceModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      image: data['image'] ?? '',
      capacity: data['capacity'] ?? 0,
      category: data['category'] ?? 'autre',
    );
  }

  // ─── Détection de chevauchement (pure) ───────────────────────────────────

  static bool overlaps(
    DateTime newStart,
    DateTime newEnd,
    DateTime existingStart,
    DateTime existingEnd,
  ) {
    return newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
  }

  // ─── Créer une réservation ────────────────────────────────────────────────

  Future<bool> createReservation({
    required String resourceId,
    required String resourceName,
    required String userId,
    required String userName,
    required DateTime startTime,
    required DateTime endTime,
    String? notes,
  }) async {
    try {
      final hasConflict = await checkConflict(resourceId, startTime, endTime);
      if (hasConflict) return false;

      await _firestore.collection('reservations').add({
        'resourceId': resourceId,
        'resourceName': resourceName,
        'userId': userId,
        'userName': userName,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'status': 'pending',
        'notes': notes ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Erreur création réservation: $e');
      return false;
    }
  }

  // ─── Vérifier les conflits ────────────────────────────────────────────────

  Future<bool> checkConflict(
    String resourceId,
    DateTime startTime,
    DateTime endTime, {
    String? excludeReservationId,
  }) async {
    final snapshot = await _firestore
        .collection('reservations')
        .where('resourceId', isEqualTo: resourceId)
        .get();

    for (final doc in snapshot.docs) {
      if (excludeReservationId != null && doc.id == excludeReservationId) {
        continue;
      }

      final data = doc.data();
      final status = data['status'] as String? ?? '';

      if (status == 'cancelled' || status == 'rejected') continue;

      final existingStart = (data['startTime'] as Timestamp).toDate();
      final existingEnd = (data['endTime'] as Timestamp).toDate();

      if (overlaps(startTime, endTime, existingStart, existingEnd)) {
        return true;
      }
    }

    return false;
  }

  // ─── Réservations d'un utilisateur ───────────────────────────────────────

  Stream<List<ReservationModel>> getUserReservations(String userId) {
    // Pas de orderBy Firestore pour éviter l'index composite
    return _firestore
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final reservations = snapshot.docs
          .map((doc) => _docToReservation(doc))
          .whereType<ReservationModel>()
          .toList();

      // Tri côté client
      reservations.sort((a, b) => b.startTime.compareTo(a.startTime));
      return reservations;
    });
  }

  // ─── Toutes les réservations (admin) ─────────────────────────────────────

  Stream<List<ReservationModel>> getAllReservations({String? statusFilter}) {
    // Pas de orderBy Firestore pour éviter l'index composite
    // Le tri est fait côté client
    Query query = _firestore.collection('reservations');

    if (statusFilter != null && statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.snapshots().map((snapshot) {
      final reservations = snapshot.docs
          .map((doc) => _docToReservation(doc))
          .whereType<ReservationModel>()
          .toList();

      // Tri côté client par date de création décroissante
      reservations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reservations;
    });
  }

  // ─── Réservations d'une ressource (vue calendrier) ───────────────────────

  Stream<List<ReservationModel>> getResourceReservations(String resourceId) {
    return _firestore
        .collection('reservations')
        .where('resourceId', isEqualTo: resourceId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => _docToReservation(doc))
          .whereType<ReservationModel>()
          .toList();
    });
  }

  // ─── Annuler une réservation ──────────────────────────────────────────────

  Future<void> cancelReservation(String reservationId) async {
    await _firestore.collection('reservations').doc(reservationId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Valider une réservation ──────────────────────────────────────────────

  Future<void> validateReservation(
    String reservationId,
    String status, {
    required String validatedBy,
  }) async {
    await _firestore.collection('reservations').doc(reservationId).update({
      'status': status,
      'validatedAt': FieldValue.serverTimestamp(),
      'validatedBy': validatedBy,
    });
  }

  // ─── Helper : convertir un doc Firestore en ReservationModel ─────────────

  ReservationModel? _docToReservation(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;

      final resourceId = (data['resourceId'] as String? ?? '').trim();
      final userId = (data['userId'] as String? ?? '').trim();
      if (resourceId.isEmpty || userId.isEmpty) return null;

      DateTime createdAt;
      if (data['createdAt'] != null) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      } else {
        createdAt = DateTime.now();
      }

      DateTime? validatedAt;
      if (data['validatedAt'] != null) {
        validatedAt = (data['validatedAt'] as Timestamp).toDate();
      }

      return ReservationModel(
        id: doc.id,
        resourceId: resourceId,
        userId: userId,
        userName: data['userName'] ?? 'Utilisateur',
        startTime: (data['startTime'] as Timestamp).toDate(),
        endTime: (data['endTime'] as Timestamp).toDate(),
        status: data['status'] ?? 'pending',
        notes: data['notes'] as String?,
        createdAt: createdAt,
        validatedAt: validatedAt,
        validatedBy: data['validatedBy'] as String?,
      );
    } catch (e) {
      print('⚠️ Doc ${doc.id} ignoré (données invalides) : $e');
      return null;
    }
  }
}
// lib/views/admin/admin_reservations_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_booking/providers/auth_provider.dart';
import 'package:flutter_booking/services/reservation_service.dart';
import 'package:flutter_booking/services/notification_service.dart';

class AdminReservationsPage extends StatefulWidget {
  const AdminReservationsPage({super.key});

  @override
  State<AdminReservationsPage> createState() => _AdminReservationsPageState();
}

class _AdminReservationsPageState extends State<AdminReservationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filter = 'pending'; // pending, confirmed, all

  Future<void> _updateReservationStatus(
      String reservationId, String status, Map<String, dynamic> reservationData) async {
    try {
      final validatedByName =
          Provider.of<UserAuthProvider>(context, listen: false).currentUser?.name ?? 'Admin';

      await ReservationService().validateReservation(
        reservationId,
        status,
        validatedBy: validatedByName,
      );

      final userId = reservationData['userId'] as String? ?? '';
      if (userId.isNotEmpty) {
        if (status == 'confirmed') {
          await NotificationService().createNotification(
            userId: userId,
            title: 'Réservation confirmée',
            message: 'Votre réservation a été confirmée par $validatedByName',
            type: 'confirmed',
            reservationId: reservationId,
          );
        } else if (status == 'rejected') {
          await NotificationService().createNotification(
            userId: userId,
            title: 'Réservation rejetée',
            message: 'Votre réservation a été rejetée par $validatedByName',
            type: 'rejected',
            reservationId: reservationId,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'confirmed'
                  ? 'Réservation confirmée avec succès'
                  : 'Réservation rejetée',
            ),
            backgroundColor: status == 'confirmed' ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteReservation(String reservationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la réservation'),
        content: const Text('Voulez-vous vraiment supprimer cette réservation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('reservations').doc(reservationId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Réservation supprimée'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtres
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildFilterChip('En attente', 'pending', Icons.pending_actions),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip('Confirmées', 'confirmed', Icons.check_circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip('Toutes', 'all', Icons.list),
              ),
            ],
          ),
        ),

        // Liste des réservations
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getReservationsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur: ${snapshot.error}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final reservations = snapshot.data!.docs;

              // Tri côté client par date décroissante (évite l'index composite Firestore)
              final sortedDocs = List.from(reservations)
                ..sort((a, b) {
                  final aT = (a.data() as Map)['createdAt'] as Timestamp?;
                  final bT = (b.data() as Map)['createdAt'] as Timestamp?;
                  if (aT == null || bT == null) return 0;
                  return bT.compareTo(aT);
                });

              if (sortedDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _filter == 'pending'
                            ? 'Aucune réservation en attente'
                            : _filter == 'confirmed'
                                ? 'Aucune réservation confirmée'
                                : 'Aucune réservation',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedDocs.length,
                itemBuilder: (context, index) {
                  final doc = sortedDocs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  DateTime startTime = (data['startTime'] as Timestamp).toDate();
                  DateTime endTime = (data['endTime'] as Timestamp).toDate();
                  String status = data['status'] ?? 'pending';
                  String? validatedBy = data['validatedBy'] as String?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['userName'] ?? 'Utilisateur',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FutureBuilder<DocumentSnapshot>(
                                      future: _firestore
                                          .collection('resources')
                                          .doc(data['resourceId'])
                                          .get(),
                                      builder: (context, resourceSnapshot) {
                                        if (resourceSnapshot.hasData &&
                                            resourceSnapshot.data!.exists) {
                                          final resourceData = resourceSnapshot.data!.data()
                                              as Map<String, dynamic>;
                                          return Text(
                                            resourceData['name'] ?? 'Ressource',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade700,
                                            ),
                                          );
                                        }
                                        return Text(
                                          'ID: ${data['resourceId']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getStatusText(status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _getStatusColor(status),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '${DateFormat('dd/MM/yyyy HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          if (data['notes'] != null &&
                              data['notes'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.note, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      data['notes'],
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Afficher validatedBy pour confirmed et rejected
                          if ((status == 'confirmed' || status == 'rejected') &&
                              validatedBy != null &&
                              validatedBy.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  Icon(Icons.verified_user,
                                      size: 14,
                                      color: _getStatusColor(status).withOpacity(0.8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Par : $validatedBy',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getStatusColor(status).withOpacity(0.8),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (status == 'pending') ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _updateReservationStatus(doc.id, 'confirmed', data);
                                    },
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Confirmer'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _updateReservationStatus(doc.id, 'rejected', data);
                                    },
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Rejeter'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (status != 'pending')
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    _deleteReservation(doc.id);
                                  },
                                  tooltip: 'Supprimer',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filter, IconData icon) {
    final isSelected = _filter == filter;
    return FilterChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : Colors.blue.shade700,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filter = filter;
        });
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: Colors.blue.shade700,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.blue.shade700,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmée';
      case 'pending':
        return 'En attente';
      case 'cancelled':
        return 'Annulée';
      case 'rejected':
        return 'Rejetée';
      default:
        return 'Inconnu';
    }
  }

  Stream<QuerySnapshot> _getReservationsStream() {
    // Pas de orderBy Firestore pour éviter l'index composite
    // Le tri est fait côté client dans le builder
    Query query = _firestore.collection('reservations');

    if (_filter == 'pending') {
      query = query.where('status', isEqualTo: 'pending');
    } else if (_filter == 'confirmed') {
      query = query.where('status', isEqualTo: 'confirmed');
    }

    return query.snapshots();
  }
}

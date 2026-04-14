// lib/views/notifications/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:flutter_booking/services/notification_service.dart';
import 'package:flutter_booking/models/notification_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final AuthService _authService = AuthService();
  final NotificationService _notifService = NotificationService();
  String _filter = 'all'; // all | unread

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Non connecté')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Filtre
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'all',
                child: Row(children: [
                  Icon(Icons.list, color: _filter == 'all' ? Colors.blue : Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Toutes'),
                ]),
              ),
              PopupMenuItem(
                value: 'unread',
                child: Row(children: [
                  Icon(Icons.mark_email_unread,
                      color: _filter == 'unread' ? Colors.blue : Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Non lues'),
                ]),
              ),
            ],
          ),
          // Tout marquer comme lu
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.white),
            tooltip: 'Tout marquer comme lu',
            onPressed: () async {
              await _notifService.markAllAsRead(user.uid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Toutes les notifications marquées comme lues'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notifService.getUserNotifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 12),
                  Text('Erreur : ${snapshot.error}',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          var notifications = snapshot.data ?? [];

          // Appliquer le filtre
          if (_filter == 'unread') {
            notifications = notifications.where((n) => !n.isRead).toList();
          }

          if (notifications.isEmpty) {
            return _EmptyNotifications(filter: _filter);
          }

          // Grouper par date
          final grouped = _groupByDate(notifications);

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: grouped.length,
            itemBuilder: (context, i) {
              final entry = grouped[i];
              if (entry is String) {
                // Séparateur de date
                return _DateSeparator(label: entry);
              }
              final notif = entry as NotificationModel;
              return _NotificationTile(
                notif: notif,
                onTap: () async {
                  await _notifService.markAsRead(notif.id);
                },
                onDelete: () async {
                  await FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(notif.id)
                      .delete();
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Groupe les notifications par date (Aujourd'hui, Hier, date)
  List<dynamic> _groupByDate(List<NotificationModel> notifications) {
    final result = <dynamic>[];
    String? lastLabel;

    for (final notif in notifications) {
      final label = _dateLabel(notif.createdAt);
      if (label != lastLabel) {
        result.add(label);
        lastLabel = label;
      }
      result.add(notif);
    }
    return result;
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return "Aujourd'hui";
    if (d == yesterday) return 'Hier';
    return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date);
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notif,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(notif.type);
    final icon = _typeIcon(notif.type);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: notif.isRead ? Colors.white : color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: notif.isRead ? Colors.grey.shade100 : color.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône colorée
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre + point non lu
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                fontWeight: notif.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (!notif.isRead)
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Message
                      Text(
                        notif.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Heure
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 11, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(notif.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const Spacer(),
                          // Badge type
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _typeLabel(notif.type),
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'confirmed':
      case 'confirmation':
        return Colors.green;
      case 'rejected':
      case 'rejection':
        return Colors.red;
      case 'cancelled':
      case 'cancellation':
        return Colors.orange;
      case 'reservation_created':
      case 'reservation':
        return const Color(0xFF2563EB);
      case 'validation':
        return Colors.purple;
      default:
        return const Color(0xFF2563EB);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'confirmed':
      case 'confirmation':
        return Icons.check_circle_outline;
      case 'rejected':
      case 'rejection':
        return Icons.cancel_outlined;
      case 'cancelled':
      case 'cancellation':
        return Icons.event_busy_outlined;
      case 'reservation_created':
      case 'reservation':
        return Icons.event_note_outlined;
      case 'validation':
        return Icons.pending_actions_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'confirmed':
      case 'confirmation':
        return 'Confirmée';
      case 'rejected':
      case 'rejection':
        return 'Rejetée';
      case 'cancelled':
      case 'cancellation':
        return 'Annulée';
      case 'reservation_created':
      case 'reservation':
        return 'Nouvelle';
      case 'validation':
        return 'À valider';
      default:
        return 'Info';
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(date);
    return DateFormat('HH:mm').format(date);
  }
}

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  final String filter;
  const _EmptyNotifications({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              filter == 'unread'
                  ? Icons.mark_email_read_outlined
                  : Icons.notifications_none_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            filter == 'unread'
                ? 'Aucune notification non lue'
                : 'Aucune notification',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filter == 'unread'
                ? 'Vous êtes à jour !'
                : 'Les notifications apparaîtront ici',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

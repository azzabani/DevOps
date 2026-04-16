// lib/views/notifications/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:flutter_booking/services/notification_service.dart';
import 'package:flutter_booking/models/notification_model.dart';
import 'package:flutter_booking/theme/app_theme.dart';
import 'package:flutter_booking/widgets/falling_resources_bg.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'all',
                child: Row(children: [
                  Icon(Icons.list_rounded,
                      color: _filter == 'all'
                          ? AppColors.primary
                          : AppColors.textTertiary),
                  const SizedBox(width: 10),
                  const Text('Toutes'),
                ]),
              ),
              PopupMenuItem(
                value: 'unread',
                child: Row(children: [
                  Icon(Icons.mark_email_unread_rounded,
                      color: _filter == 'unread'
                          ? AppColors.primary
                          : AppColors.textTertiary),
                  const SizedBox(width: 10),
                  const Text('Non lues'),
                ]),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Colors.white),
            tooltip: 'Tout marquer comme lu',
            onPressed: () async {
              await _notifService.markAllAsRead(user.uid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Toutes les notifications marquées comme lues'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 2),
                ));
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const FallingResourcesBg(count: 16, globalOpacity: 0.65),
          StreamBuilder<List<NotificationModel>>(
        stream: _notifService.getUserNotifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline_rounded,
                        size: 40, color: AppColors.error),
                  ),
                  const SizedBox(height: 12),
                  Text('Erreur : ${snapshot.error}',
                      style: const TextStyle(color: AppColors.textSecondary)),
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
            padding: const EdgeInsets.only(bottom: 20, top: 8),
            itemCount: grouped.length,
            itemBuilder: (context, i) {
              final entry = grouped[i];
              if (entry is String) {
                return _DateSeparator(label: entry);
              }
              final notif = entry as NotificationModel;
              return _AnimatedNotificationTile(
                notif: notif,
                index: i,
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
        ],
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

class _AnimatedNotificationTile extends StatefulWidget {
  final NotificationModel notif;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AnimatedNotificationTile({
    required this.notif,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_AnimatedNotificationTile> createState() =>
      _AnimatedNotificationTileState();
}

class _AnimatedNotificationTileState extends State<_AnimatedNotificationTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0.1, 0), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(
        Duration(milliseconds: (widget.index * 40).clamp(0, 400)),
        () => _controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(widget.notif.type);
    final icon = _typeIcon(widget.notif.type);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Dismissible(
          key: Key(widget.notif.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          onDismissed: (_) => widget.onDelete(),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: widget.notif.isRead
                    ? AppColors.surface
                    : color.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.notif.isRead
                      ? AppColors.border
                      : color.withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.notif.title,
                                  style: TextStyle(
                                    fontWeight: widget.notif.isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (!widget.notif.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.notif.message,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 11, color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                _formatTime(widget.notif.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _typeLabel(widget.notif.type),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: color,
                                    fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'confirmed':
      case 'confirmation':
        return AppColors.success;
      case 'rejected':
      case 'rejection':
        return AppColors.error;
      case 'cancelled':
      case 'cancellation':
        return AppColors.warning;
      case 'validation':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'confirmed':
      case 'confirmation':
        return Icons.check_circle_rounded;
      case 'rejected':
      case 'rejection':
        return Icons.cancel_rounded;
      case 'cancelled':
      case 'cancellation':
        return Icons.event_busy_rounded;
      case 'validation':
        return Icons.pending_actions_rounded;
      default:
        return Icons.notifications_rounded;
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
          Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.border)),
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
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              filter == 'unread'
                  ? Icons.mark_email_read_rounded
                  : Icons.notifications_none_rounded,
              size: 52,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            filter == 'unread'
                ? 'Aucune notification non lue'
                : 'Aucune notification',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filter == 'unread' ? 'Vous êtes à jour !' : 'Les notifications apparaîtront ici',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

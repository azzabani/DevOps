// lib/views/admin/admin_users_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _roleFilter = 'all';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateRole(String userId, String currentRole) async {
    String? newRole = currentRole;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le rôle'),
        content: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _roleOption(ctx, setS, newRole!, 'user', '👤 Utilisateur'),
              _roleOption(ctx, setS, newRole, 'manager', '📊 Manager'),
              _roleOption(ctx, setS, newRole, 'admin', '🛡️ Administrateur'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestore.collection('users').doc(userId).update({
                'role': newRole,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Rôle mis à jour : $newRole'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Widget _roleOption(BuildContext ctx, StateSetter setS, String current,
      String value, String label) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: current,
      onChanged: (v) => setS(() => current = v!),
      activeColor: const Color(0xFF2563EB),
    );
  }

  Future<void> _toggleActive(
      String userId, bool currentActive, String userName) async {
    final action = currentActive ? 'désactiver' : 'réactiver';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${currentActive ? 'Désactiver' : 'Réactiver'} le compte'),
        content: Text(
            'Voulez-vous vraiment $action le compte de "$userName" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentActive ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(currentActive ? 'Désactiver' : 'Réactiver'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.collection('users').doc(userId).update({
        'active': !currentActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Compte ${!currentActive ? 'réactivé' : 'désactivé'} avec succès'),
            backgroundColor: !currentActive ? Colors.green : Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: Text(
            'Voulez-vous vraiment supprimer définitivement le compte de "$userName" ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.collection('users').doc(userId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte supprimé'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre de recherche + filtre rôle
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom ou email…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('Tous', 'all'),
                    const SizedBox(width: 8),
                    _filterChip('👤 Utilisateurs', 'user'),
                    const SizedBox(width: 8),
                    _filterChip('📊 Managers', 'manager'),
                    const SizedBox(width: 8),
                    _filterChip('🛡️ Admins', 'admin'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Liste des utilisateurs
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erreur : ${snapshot.error}'));
              }

              var docs = snapshot.data!.docs;

              // Filtre rôle
              if (_roleFilter != 'all') {
                docs = docs
                    .where((d) =>
                        (d.data() as Map<String, dynamic>)['role'] ==
                        _roleFilter)
                    .toList();
              }

              // Filtre recherche
              if (_searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Aucun utilisateur trouvé',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Sans nom';
                  final email = data['email'] ?? '';
                  final role = data['role'] ?? 'user';
                  final active = data['active'] ?? true;
                  final createdAt = data['createdAt'] != null
                      ? (data['createdAt'] as Timestamp).toDate()
                      : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: _roleColor(role).withOpacity(0.15),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: _roleColor(role),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Infos
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: active
                                              ? Colors.black87
                                              : Colors.grey,
                                          decoration: active
                                              ? null
                                              : TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ),
                                    _roleBadge(role),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                                if (createdAt != null)
                                  Text(
                                    'Inscrit le ${DateFormat('dd/MM/yyyy').format(createdAt)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400),
                                  ),
                                if (!active)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.orange.shade200),
                                    ),
                                    child: Text(
                                      'Compte désactivé',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange.shade700),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Actions
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.grey),
                            onSelected: (action) {
                              switch (action) {
                                case 'role':
                                  _updateRole(doc.id, role);
                                  break;
                                case 'toggle':
                                  _toggleActive(doc.id, active, name);
                                  break;
                                case 'delete':
                                  _deleteUser(doc.id, name);
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'role',
                                child: Row(children: [
                                  Icon(Icons.manage_accounts,
                                      size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Modifier le rôle'),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(children: [
                                  Icon(
                                    active
                                        ? Icons.block
                                        : Icons.check_circle_outline,
                                    size: 18,
                                    color: active
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(active ? 'Désactiver' : 'Réactiver'),
                                ]),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete_outline,
                                      size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Supprimer',
                                      style: TextStyle(color: Colors.red)),
                                ]),
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

  Widget _filterChip(String label, String value) {
    final selected = _roleFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _roleFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? const Color(0xFF2563EB)
                  : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final color = _roleColor(role);
    final label = role == 'admin'
        ? 'Admin'
        : role == 'manager'
            ? 'Manager'
            : 'User';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.purple;
      default:
        return const Color(0xFF2563EB);
    }
  }
}

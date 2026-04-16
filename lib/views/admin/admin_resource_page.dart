// lib/views/admin/admin_resource_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_booking/models/resource_model.dart';
import 'package:flutter_booking/theme/app_theme.dart';
import 'package:flutter_booking/views/admin/add_edit_resource_page.dart';

class AdminResourcePage extends StatefulWidget {
  const AdminResourcePage({super.key});

  @override
  State<AdminResourcePage> createState() => _AdminResourcePageState();
}

class _AdminResourcePageState extends State<AdminResourcePage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedCategory = 'tous';

  // Catégories normalisées en minuscules
  static const _categories = ['tous', 'salle', 'véhicule', 'ordinateur', 'matériel'];

  late AnimationController _fabController;
  late Animation<double> _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fabAnim = CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack);
    Future.delayed(const Duration(milliseconds: 400), () => _fabController.forward());
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  Color _catColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'salle':      return AppColors.salle;
      case 'véhicule':   return AppColors.vehicule;
      case 'ordinateur': return AppColors.ordinateur;
      case 'matériel':   return AppColors.materiel;
      default:           return AppColors.textTertiary;
    }
  }

  IconData _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'salle':      return Icons.meeting_room_rounded;
      case 'véhicule':   return Icons.directions_car_rounded;
      case 'ordinateur': return Icons.computer_rounded;
      case 'matériel':   return Icons.build_rounded;
      default:           return Icons.inventory_2_rounded;
    }
  }

  void _openForm({ResourceModel? resource}) {
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, a, __) => AddEditResourcePage(resource: resource),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  Future<void> _deleteResource(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer la ressource',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer "$name" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _firestore.collection('resources').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ressource supprimée'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: ScaleTransition(
        scale: _fabAnim,
        child: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter',
              style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      body: Column(
        children: [
          // ── Filtres catégories ──────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final selected = cat == _selectedCategory;
                  final color = cat == 'tous' ? AppColors.primary : _catColor(cat);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: FilterChip(
                        label: Text(
                          cat == 'tous' ? 'TOUS' : cat.toUpperCase(),
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                        backgroundColor: AppColors.surfaceVariant,
                        selectedColor: color,
                        showCheckmark: false,
                        side: BorderSide(
                            color: selected ? color : AppColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Liste ───────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedCategory == 'tous'
                  ? _firestore.collection('resources').snapshots()
                  : _firestore
                      .collection('resources')
                      // Cherche les deux casses pour compatibilité
                      .where('category', isEqualTo: _selectedCategory)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur : ${snapshot.error}',
                        style: const TextStyle(color: AppColors.error)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary));
                }

                final docs = snapshot.data!.docs;

                // Filtre côté client pour gérer les deux casses
                final filtered = _selectedCategory == 'tous'
                    ? docs
                    : docs.where((d) {
                        final cat = ((d.data() as Map<String, dynamic>)['category']
                                as String? ?? '')
                            .toLowerCase()
                            .trim();
                        return cat == _selectedCategory;
                      }).toList();

                if (filtered.isEmpty) {
                  return _EmptyState(onAdd: () => _openForm());
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final doc  = filtered[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final resource = ResourceModel(
                      id:          doc.id,
                      name:        data['name'] ?? '',
                      description: data['description'] ?? '',
                      image:       data['image'] ?? '',
                      capacity:    (data['capacity'] as num?)?.toInt() ?? 0,
                      category:    (data['category'] as String? ?? '').toLowerCase(),
                    );
                    return _ResourceAdminCard(
                      resource:  resource,
                      catColor:  _catColor(resource.category),
                      catIcon:   _catIcon(resource.category),
                      onEdit:    () => _openForm(resource: resource),
                      onDelete:  () => _deleteResource(resource.id, resource.name),
                      index:     i,
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

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _ResourceAdminCard extends StatefulWidget {
  final ResourceModel resource;
  final Color catColor;
  final IconData catIcon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int index;

  const _ResourceAdminCard({
    required this.resource,
    required this.catColor,
    required this.catIcon,
    required this.onEdit,
    required this.onDelete,
    required this.index,
  });

  @override
  State<_ResourceAdminCard> createState() => _ResourceAdminCardState();
}

class _ResourceAdminCardState extends State<_ResourceAdminCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 350 + widget.index * 50));
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 50),
        () => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resource;
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: widget.catColor.withOpacity(0.06),
                blurRadius: 14, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Barre couleur catégorie
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: widget.catColor,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Image / icône
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: widget.catColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: r.isNetworkImage
                            ? Image.network(r.image, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                    widget.catIcon,
                                    color: widget.catColor, size: 28))
                            : Icon(widget.catIcon,
                                color: widget.catColor, size: 28),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Infos
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text(r.description,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(r.capacityIcon,
                                size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(r.capacityLabel,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.catColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                r.category.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 9,
                                    color: widget.catColor,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),

                    // Actions
                    Column(
                      children: [
                        _ActionBtn(
                          icon: Icons.edit_rounded,
                          color: AppColors.primary,
                          onTap: widget.onEdit,
                          tooltip: 'Modifier',
                        ),
                        const SizedBox(height: 6),
                        _ActionBtn(
                          icon: Icons.delete_rounded,
                          color: AppColors.error,
                          onTap: widget.onDelete,
                          tooltip: 'Supprimer',
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
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_rounded,
                size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('Aucune ressource',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          const Text('Ajoutez votre première ressource',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter une ressource'),
          ),
        ],
      ),
    );
  }
}

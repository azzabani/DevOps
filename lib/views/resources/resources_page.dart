// lib/views/resources/resources_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_booking/models/resource_model.dart';
import 'package:flutter_booking/data/resources_data.dart';
import 'package:flutter_booking/theme/app_theme.dart';
import 'package:flutter_booking/widgets/falling_resources_bg.dart';

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedCategory = 'Tous';
  // Toujours lire depuis Firestore — les ressources admin y sont stockées
  bool _useLocalData = false;
  RangeValues _capacityRange = const RangeValues(0, 100);
  bool _showCapacityFilter = false;

  late AnimationController _headerController;
  late AnimationController _listController;
  late Animation<double> _headerAnim;

  List<String> get _categories => ResourcesData.getCategories();

  List<ResourceModel> get _filteredLocalResources =>
      ResourcesData.getCategories()
          .where((c) => c != 'Tous')
          .map((_) => <ResourceModel>[])
          .expand((e) => e)
          .toList(); // vide — plus de données locales

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _listController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _headerAnim =
        CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerController.forward();
    Future.delayed(
        const Duration(milliseconds: 200), () => _listController.forward());
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _resetListAnim() {
    _listController.reset();
    _listController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const FallingResourcesBg(count: 18, globalOpacity: 0.65),
          NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            snap: true,
            pinned: false,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: FadeTransition(
                opacity: _headerAnim,
                child: Container(
                  decoration:
                      const BoxDecoration(gradient: AppColors.gradientPrimary),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                      ),
                      const SafeArea(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('Ressources',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5)),
                              SizedBox(height: 2),
                              Text('Trouvez et réservez',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              // Bouton importer supprimé — les ressources sont gérées par l'admin
            ],
          ),
        ],
        body: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: _buildFirestoreList(),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // Catégories
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: FilterChip(
                      label: Text(cat.toUpperCase(),
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          )),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                        _resetListAnim();
                      },
                      backgroundColor: AppColors.surfaceVariant,
                      selectedColor: AppColors.primary,
                      showCheckmark: false,
                      side: BorderSide(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                );
              },
            ),
          ),
          // Filtre capacité
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                InkWell(
                  onTap: () =>
                      setState(() => _showCapacityFilter = !_showCapacityFilter),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded,
                            size: 16, color: AppColors.textTertiary),
                        const SizedBox(width: 6),
                        Text(
                          'Filtre capacité : ${_capacityRange.start.toInt()} – ${_capacityRange.end.toInt()}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const Spacer(),
                        AnimatedRotation(
                          turns: _showCapacityFilter ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: _showCapacityFilter
                      ? RangeSlider(
                          values: _capacityRange,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          activeColor: AppColors.primary,
                          inactiveColor: AppColors.border,
                          labels: RangeLabels(
                            '${_capacityRange.start.toInt()}',
                            '${_capacityRange.end.toInt()}',
                          ),
                          onChanged: (v) {
                            setState(() => _capacityRange = v);
                            _resetListAnim();
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildLocalList() {
    final resources = _filteredLocalResources;
    if (resources.isEmpty) return _EmptyResources();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: resources.length,
      itemBuilder: (_, i) => _AnimatedResourceCard(
        resource: resources[i],
        index: i,
        controller: _listController,
        onTap: () => Navigator.pushNamed(context, '/resource_detail',
            arguments: resources[i]),
      ),
    );
  }

  Widget _buildFirestoreList() {
    // Toujours récupérer toutes les ressources et filtrer côté client
    // pour gérer les deux casses ('Salle' et 'salle')
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('resources').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(onRetry: _importResourcesToFirestore);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _EmptyResources();
        }

        // Filtre catégorie + capacité côté client (insensible à la casse)
        final resources = docs
            .map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return ResourceModel(
                id:          doc.id,
                name:        d['name'] ?? '',
                description: d['description'] ?? '',
                image:       d['image'] ?? '',
                capacity:    (d['capacity'] as num?)?.toInt() ?? 0,
                category:    (d['category'] as String? ?? '').toLowerCase(),
              );
            })
            .where((r) {
              final catOk = _selectedCategory == 'Tous' ||
                  r.category == _selectedCategory.toLowerCase();
              final capOk = r.capacity >= _capacityRange.start &&
                  r.capacity <= _capacityRange.end;
              return catOk && capOk;
            })
            .toList();

        if (resources.isEmpty) return _EmptyResources();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: resources.length,
          itemBuilder: (_, i) => _AnimatedResourceCard(
            resource: resources[i],
            index: i,
            controller: _listController,
            onTap: () => Navigator.pushNamed(context, '/resource_detail',
                arguments: resources[i]),
          ),
        );
      },
    );
  }

  Future<void> _importResourcesToFirestore() async {
    // Méthode conservée pour compatibilité mais sans données locales
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _AnimatedResourceCard extends StatefulWidget {
  final ResourceModel resource;
  final int index;
  final AnimationController controller;
  final VoidCallback onTap;

  const _AnimatedResourceCard({
    required this.resource,
    required this.index,
    required this.controller,
    required this.onTap,
  });

  @override
  State<_AnimatedResourceCard> createState() => _AnimatedResourceCardState();
}

class _AnimatedResourceCardState extends State<_AnimatedResourceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _elevAnim;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _elevAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  Color _catColor() {
    switch (widget.resource.category.toLowerCase()) {
      case 'salle':
        return AppColors.salle;
      case 'véhicule':
        return AppColors.vehicule;
      case 'ordinateur':
        return AppColors.ordinateur;
      case 'matériel':
        return AppColors.materiel;
      default:
        return AppColors.textTertiary;
    }
  }

  IconData _catIcon() {
    switch (widget.resource.category.toLowerCase()) {
      case 'salle':
        return Icons.meeting_room_rounded;
      case 'véhicule':
        return Icons.directions_car_rounded;
      case 'ordinateur':
        return Icons.computer_rounded;
      case 'matériel':
        return Icons.build_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _catColor();
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, child) {
        final delay = widget.index * 80;
        final t = Curves.easeOutCubic.transform(
          ((widget.controller.value * 1000 - delay) / 500).clamp(0.0, 1.0),
        );
        return Transform.translate(
          offset: Offset(0, 20 * (1 - t)),
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _hoverController.forward(),
        onTapUp: (_) {
          _hoverController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _hoverController.reverse(),
        child: AnimatedBuilder(
          animation: _elevAnim,
          builder: (_, child) => Transform.scale(
            scale: 1.0 - 0.02 * _elevAnim.value,
            child: child,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Image / icône
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _buildImage(color),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.resource.name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(widget.resource.description,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(widget.resource.capacityIcon,
                                size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(widget.resource.capacityLabel,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.resource.category.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 9,
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(Color color) {
    final r = widget.resource;
    if (r.isNetworkImage) {
      return Image.network(r.image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(_catIcon(), size: 32, color: color));
    }
    if (r.image.isNotEmpty && r.image.startsWith('assets/')) {
      return Image.asset(r.getImagePath(),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(_catIcon(), size: 32, color: color));
    }
    return Icon(_catIcon(), size: 32, color: color);
  }
}

class _EmptyResources extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.search_off_rounded,
                size: 48, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          const Text('Aucune ressource disponible',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          const Text('Essayez une autre catégorie',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _EmptyFirestore extends StatelessWidget {
  final VoidCallback onImport;
  const _EmptyFirestore({required this.onImport});

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          const Text('Aucune ressource dans Firestore',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Importer les ressources'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.errorSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
          ),
          const SizedBox(height: 16),
          const Text('Erreur de chargement',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

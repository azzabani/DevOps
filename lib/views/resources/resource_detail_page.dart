// lib/views/resources/resource_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_booking/models/resource_model.dart';
import 'package:flutter_booking/theme/app_theme.dart';
import 'package:flutter_booking/widgets/falling_resources_bg.dart';

class ResourceDetailPage extends StatefulWidget {
  final ResourceModel resource;

  const ResourceDetailPage({
    super.key,
    required this.resource,
  });

  @override
  State<ResourceDetailPage> createState() => _ResourceDetailPageState();
}

class _ResourceDetailPageState extends State<ResourceDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(
        const Duration(milliseconds: 200), () => _controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
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
    final resource = widget.resource;
    final color = _getCategoryColor(resource.category);

    return Scaffold(
      body: Stack(
        children: [
          const FallingResourcesBg(count: 14, globalOpacity: 0.6),
          CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: color,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                resource.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 8)]),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  resource.isNetworkImage
                      ? Image.network(resource.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildFallbackBg(color, resource.category))
                      : _buildFallbackBg(color, resource.category),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.6),
                        ],
                        stops: const [0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges
                      Row(
                        children: [
                          _Badge(
                            icon: _getCategoryIcon(resource.category),
                            label: resource.category.toUpperCase(),
                            color: color,
                          ),
                          const SizedBox(width: 10),
                          _Badge(
                            icon: resource.capacityIcon,
                            label: resource.capacityLabel,
                            color: AppColors.textSecondary,
                            outlined: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Description
                      _InfoCard(
                        icon: Icons.description_rounded,
                        title: 'Description',
                        child: Text(
                          resource.description,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Infos pratiques
                      _InfoCard(
                        icon: Icons.info_outline_rounded,
                        title: 'Informations pratiques',
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.category_rounded,
                              label: 'Catégorie',
                              value: resource.category,
                              color: color,
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              icon: resource.capacityIcon,
                              label: 'Capacité',
                              value: resource.capacityLabel,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              icon: Icons.check_circle_rounded,
                              label: 'Disponibilité',
                              value: 'Disponible',
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bouton réserver
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                              context, '/booking',
                              arguments: resource),
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: const Text('Réserver cette ressource'),
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                            shadowColor: color.withOpacity(0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackBg(Color color, String category) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.7)],
        ),
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(category),
          size: 100,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool outlined;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: outlined ? AppColors.border : color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: outlined ? AppColors.textSecondary : color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: outlined ? AppColors.textSecondary : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}
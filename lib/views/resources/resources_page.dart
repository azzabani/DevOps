// lib/views/resources/resources_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_booking/models/resource_model.dart';
import 'package:flutter_booking/data/resources_data.dart';

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedCategory = 'Tous';
  bool _useLocalData = true;
  int _minCapacity = 0;
  int _maxCapacity = 100;
  RangeValues _capacityRange = const RangeValues(0, 100);
  bool _showCapacityFilter = false;
  
  List<String> get _categories => ResourcesData.getCategories();
  
  List<ResourceModel> get _filteredLocalResources {
    final resources = ResourcesData.resources;
    return resources.where((r) {
      final categoryMatch =
          _selectedCategory == 'Tous' || r.category == _selectedCategory;
      final capacityMatch = r.capacity >= _capacityRange.start &&
          r.capacity <= _capacityRange.end;
      return categoryMatch && capacityMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ressources disponibles'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_useLocalData ? Icons.cloud_off : Icons.cloud),
            onPressed: () {
              setState(() {
                _useLocalData = !_useLocalData;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _useLocalData 
                        ? 'Mode hors-ligne : données locales' 
                        : 'Mode online : Firestore',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            tooltip: _useLocalData ? 'Données locales' : 'Firestore',
          ),
          if (!_useLocalData)
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: () => _importResourcesToFirestore(),
              tooltip: 'Importer les ressources',
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    backgroundColor: Colors.grey.shade200,
                    selectedColor: Colors.blue.shade700,
                  ),
                );
              },
            ),
          ),

          // Filtre capacité
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                InkWell(
                  onTap: () =>
                      setState(() => _showCapacityFilter = !_showCapacityFilter),
                  child: Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Capacité : ${_capacityRange.start.toInt()} – ${_capacityRange.end.toInt()} personnes',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      Icon(
                        _showCapacityFilter
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ),
                if (_showCapacityFilter)
                  RangeSlider(
                    values: _capacityRange,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    labels: RangeLabels(
                      '${_capacityRange.start.toInt()}',
                      '${_capacityRange.end.toInt()}',
                    ),
                    activeColor: Colors.blue.shade700,
                    onChanged: (v) => setState(() => _capacityRange = v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _useLocalData
                ? _buildLocalResourcesList()
                : _buildFirestoreResourcesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalResourcesList() {
    final resources = _filteredLocalResources;
    
    if (resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune ressource disponible',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sélectionnez une autre catégorie',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: resources.length,
      itemBuilder: (context, index) {
        final resource = resources[index];
        return _buildResourceCard(resource);
      },
    );
  }

  Widget _buildFirestoreResourcesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _selectedCategory == 'Tous'
          ? _firestore.collection('resources').snapshots()
          : _firestore
              .collection('resources')
              .where('category', isEqualTo: _selectedCategory)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Erreur: ${snapshot.error}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _importResourcesToFirestore(),
                  child: const Text('Importer les ressources'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final resources = snapshot.data!.docs;
        
        if (resources.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: 60,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune ressource dans Firestore',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Appuyez sur le bouton 📤 pour importer',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _importResourcesToFirestore(),
                  icon: const Icon(Icons.upload),
                  label: const Text('Importer les ressources'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: resources.length,
          itemBuilder: (context, index) {
            final doc = resources[index];
            final data = doc.data() as Map<String, dynamic>;
            final resource = ResourceModel(
              id: doc.id,
              name: data['name'] ?? '',
              description: data['description'] ?? '',
              image: data['image'] ?? '',
              capacity: data['capacity'] ?? 0,
              category: data['category'] ?? 'autre',
            );
            return _buildResourceCard(resource);
          },
        );
      },
    );
  }

  Widget _buildResourceCard(ResourceModel resource) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/resource_detail',
            arguments: resource,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getCategoryColor(resource.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: resource.image.isNotEmpty && resource.image.startsWith('assets/')
                      ? Image.asset(
                          resource.getImagePath(),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              _getCategoryIcon(resource.category),
                              size: 30,
                              color: _getCategoryColor(resource.category),
                            );
                          },
                        )
                      : Icon(
                          _getCategoryIcon(resource.category),
                          size: 30,
                          color: _getCategoryColor(resource.category),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resource.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.group,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${resource.capacity} personnes',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(resource.category).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            resource.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getCategoryColor(resource.category),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importResourcesToFirestore() async {
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importer les ressources'),
        content: Text(
          'Voulez-vous importer ${ResourcesData.resources.length} ressources dans Firestore ?\n\n'
          'Attention : Les ressources existantes avec les mêmes IDs seront écrasées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
            ),
            child: const Text('Importer'),
          ),
        ],
      ),
    );

    if (shouldImport != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Importation en cours...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      for (var resource in ResourcesData.resources) {
        await _firestore.collection('resources').doc(resource.id).set({
          'name': resource.name,
          'description': resource.description,
          'image': resource.image,
          'capacity': resource.capacity,
          'category': resource.category,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${ResourcesData.resources.length} ressources importées avec succès !'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        setState(() {
          _useLocalData = false;
        });
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de l\'importation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'salle':
        return Icons.meeting_room;
      case 'véhicule':
        return Icons.directions_car;
      case 'ordinateur':
        return Icons.computer;
      case 'matériel':
        return Icons.build;
      default:
        return Icons.inventory;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'salle':
        return Colors.blue;
      case 'véhicule':
        return Colors.green;
      case 'ordinateur':
        return Colors.purple;
      case 'matériel':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
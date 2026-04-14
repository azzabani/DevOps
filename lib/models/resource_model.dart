// lib/models/resource_model.dart
class ResourceModel {
  final String id;
  final String name;
  final String description;
  final String image;
  final int capacity;
  final String category;

  ResourceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.capacity,
    required this.category,
  });

  // Méthode pour obtenir le chemin de l'image
  String getImagePath() {
    if (image.isNotEmpty && image.startsWith('assets/')) {
      return image;
    }
    
    // Images par défaut selon la catégorie
    switch (category.toLowerCase()) {
      case 'salle':
        return 'assets/images/salle.jpg';
      case 'véhicule':
        return 'assets/images/voiture.webp';
      case 'ordinateur':
        return 'assets/images/ordinateur.jpg';
      case 'matériel':
        return 'assets/images/table.jpg';
      default:
        return 'assets/images/default.png';
    }
  }

  // Convertir vers Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'image': image,
      'capacity': capacity,
      'category': category,
    };
  }

  // Convertir depuis Firestore
  factory ResourceModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ResourceModel(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      image: data['image'] ?? '',
      capacity: data['capacity'] ?? 0,
      category: data['category'] ?? 'autre',
    );
  }
}
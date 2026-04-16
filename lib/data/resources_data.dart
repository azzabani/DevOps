// lib/data/resources_data.dart
// Les ressources sont gérées exclusivement via Firestore par l'administrateur.
// Ce fichier ne contient plus de données statiques.

class ResourcesData {
  /// Catégories disponibles (normalisées en minuscules)
  static const List<String> categories = [
    'salle',
    'véhicule',
    'ordinateur',
    'matériel',
  ];

  /// Catégories avec "Tous" pour les filtres
  static List<String> getCategories() => ['Tous', ...categories];
}

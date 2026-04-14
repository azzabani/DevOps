import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/resource_model.dart';

class ResourceProvider extends ChangeNotifier {
  List<ResourceModel> _resources = [];
  String? _categoryFilter;
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot>? _subscription;

  List<ResourceModel> get resources => _filteredResources();
  List<ResourceModel> get allResources => _resources;
  String? get categoryFilter => _categoryFilter;
  bool get isLoading => _isLoading;

  void initialize() {
    _isLoading = true;
    notifyListeners();

    _subscription = FirebaseFirestore.instance
        .collection('resources')
        .snapshots()
        .listen((snapshot) {
      _resources = snapshot.docs
          .map((doc) => ResourceModel.fromFirestore(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  List<ResourceModel> _filteredResources() {
    if (_categoryFilter == null) return _resources;
    return _resources
        .where((r) =>
            r.category.toLowerCase() == _categoryFilter!.toLowerCase())
        .toList();
  }

  Future<void> createResource(ResourceModel r) async {
    await FirebaseFirestore.instance
        .collection('resources')
        .add(r.toFirestore());
  }

  Future<void> updateResource(ResourceModel r) async {
    await FirebaseFirestore.instance
        .collection('resources')
        .doc(r.id)
        .update(r.toFirestore());
  }

  Future<void> deleteResource(String id) async {
    await FirebaseFirestore.instance
        .collection('resources')
        .doc(id)
        .delete();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

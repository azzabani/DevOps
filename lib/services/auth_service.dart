// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream de l'utilisateur connecté
  Stream<User?> get user => _auth.authStateChanges();

  // Getter pour l'utilisateur courant
  User? get currentUser => _auth.currentUser;

  // Connexion
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Inscription
  Future<UserCredential> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sauvegarder les données utilisateur dans Firestore
  Future<void> saveUserData({
    required String userId,
    required String name,
    required String email,
    required String role,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'name': name,
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Récupérer les données utilisateur
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Récupérer les données de l'utilisateur courant
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    User? user = currentUser;
    if (user == null) return null;
    return await getUserData(user.uid);
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Réinitialisation du mot de passe
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Vérifier si l'utilisateur est admin
  Future<bool> isAdmin() async {
    User? user = currentUser;
    if (user == null) return false;
    
    var doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return doc.data()?['role'] == 'admin';
    }
    return false;
  }

  // Vérifier si l'utilisateur est manager
  Future<bool> isManager() async {
    User? user = currentUser;
    if (user == null) return false;
    
    var doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      String? role = doc.data()?['role'];
      return role == 'manager' || role == 'admin';
    }
    return false;
  }

  // Récupérer le rôle de l'utilisateur
  Future<String?> getUserRole() async {
    User? user = currentUser;
    if (user == null) return null;
    
    var doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return doc.data()?['role'];
    }
    return null;
  }

  // Mettre à jour le profil utilisateur
  Future<void> updateUserProfile({
    String? name,
    String? email,
  }) async {
    User? user = currentUser;
    if (user == null) return;

    // Mettre à jour Firestore
    if (name != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Mettre à jour l'email si nécessaire
    if (email != null && email != user.email) {
      await user.updateEmail(email);
      await _firestore.collection('users').doc(user.uid).update({
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
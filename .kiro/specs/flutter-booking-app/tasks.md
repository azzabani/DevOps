# Plan d'implémentation : FlutterBooking

## Vue d'ensemble

Complétion et consolidation de l'application Flutter de réservation de ressources partagées. Les tâches couvrent la mise à jour des dépendances, l'enrichissement des modèles et services existants, la complétion des providers, la création des nouveaux services (PDF, iCal), l'enrichissement des vues admin et notifications, et l'intégration du badge de notifications.

## Tâches

- [x] 1. Mettre à jour les dépendances dans `pubspec.yaml`
  - Ajouter `share_plus: ^10.0.0` dans la section `dependencies`
  - _Requirements: 11.2, 12.2_

- [x] 2. Enrichir `UserModel` et créer `NotificationModel`
  - [x] 2.1 Enrichir `lib/models/user_model.dart`
    - Ajouter les champs `createdAt` et `updatedAt` (DateTime)
    - Implémenter `factory UserModel.fromFirestore(Map<String, dynamic> data, String id)`
    - Implémenter `Map<String, dynamic> toFirestore()`
    - Ajouter les getters `bool get isAdmin` et `bool get isManager`
    - _Requirements: 1.2, 1.5, 1.6, 1.7_
  - [x] 2.2 Créer `lib/models/notification_model.dart`
    - Définir les champs : `id`, `userId`, `title`, `message`, `type`, `reservationId`, `isRead`, `createdAt`
    - Implémenter `factory NotificationModel.fromFirestore(Map<String, dynamic> data, String id)`
    - Implémenter `Map<String, dynamic> toFirestore()`
    - _Requirements: 9.1_

- [x] 3. Compléter les providers
  - [x] 3.1 Compléter `lib/providers/auth_provider.dart` (`UserAuthProvider`)
    - Déclarer `UserModel? _currentUser`, `bool _isLoading`, `String? _error`
    - Exposer les getters `currentUser`, `isLoading`, `isAdmin`, `isManager`, `error`
    - Implémenter `loadCurrentUser(String userId)` via `AuthService`
    - Implémenter `updateProfile(String name)` via `AuthService`
    - Implémenter `clear()` pour réinitialiser l'état à la déconnexion
    - _Requirements: 1.2, 1.5, 1.6, 1.7, 2.2, 10.4_
  - [x] 3.2 Compléter `lib/providers/resource_provider.dart` (`ResourceProvider`)
    - Déclarer `List<ResourceModel> _resources`, `String? _categoryFilter`, `bool _isLoading`, `StreamSubscription? _subscription`
    - Implémenter `initialize()` pour démarrer le stream Firestore sur la collection `resources`
    - Implémenter `setCategoryFilter(String? category)` avec `notifyListeners()`
    - Implémenter `_filteredResources()` retournant les ressources filtrées par catégorie
    - Implémenter `createResource`, `updateResource`, `deleteResource` via Firestore
    - Surcharger `dispose()` pour annuler le stream
    - _Requirements: 3.1, 3.2, 4.2, 4.3, 4.4, 10.2_
  - [ ]* 3.3 Écrire le test de propriété pour le filtrage par catégorie (Propriété 7)
    - **Propriété 7 : Correction du filtrage par catégorie**
    - **Validates: Requirements 3.2**
  - [x] 3.4 Compléter `lib/providers/calendar_provider.dart` (`CalendarProvider`)
    - Déclarer `DateTime _selectedDay`, `String? _currentResourceId`, `List<ReservationModel> _resourceReservations`, `StreamSubscription? _subscription`
    - Implémenter `selectDay(DateTime day)` avec `notifyListeners()`
    - Implémenter `loadResourceReservations(String resourceId)` via stream Firestore filtré sur `resourceId` et statuts `pending`/`confirmed`
    - Implémenter `getOccupiedHours(DateTime day)` retournant la liste des heures occupées pour un jour donné
    - Implémenter `isSlotAvailable(DateTime start, DateTime end)` en logique pure
    - Surcharger `dispose()` pour annuler le stream
    - _Requirements: 5.1, 5.3, 5.4, 10.3_
  - [ ]* 3.5 Écrire le test de propriété pour la validation de créneau (Propriété 6)
    - **Propriété 6 : Validation de créneau (endTime > startTime)**
    - **Validates: Requirements 5.5**

- [x] 4. Enrichir `ReservationService`
  - [x] 4.1 Mettre à jour `lib/services/reservation_service.dart`
    - Modifier `createReservation` pour accepter et enregistrer `resourceName` dans Firestore
    - Modifier `validateReservation` pour accepter et enregistrer `validatedBy` et `validatedAt`
    - Modifier `checkConflict` pour accepter le paramètre optionnel `excludeReservationId` (pour la modification)
    - Extraire la méthode statique pure `overlaps(DateTime newStart, DateTime newEnd, DateTime existingStart, DateTime existingEnd)` pour la détection de chevauchement
    - _Requirements: 6.1, 6.2, 6.3, 6.6, 7.2, 7.3, 8.4_
  - [ ]* 4.2 Écrire le test de propriété pour la détection de chevauchement (Propriété 1)
    - **Propriété 1 : Correction de la détection de chevauchement**
    - **Validates: Requirements 6.1, 6.6**
  - [ ]* 4.3 Écrire le test de propriété pour la symétrie de la détection de conflit (Propriété 2)
    - **Propriété 2 : Symétrie de la détection de conflit**
    - **Validates: Requirements 6.6**

- [x] 5. Enrichir `NotificationService`
  - [x] 5.1 Mettre à jour `lib/services/notification_service.dart`
    - Modifier `getUserNotifications(String userId)` pour retourner `Stream<List<NotificationModel>>`
    - Modifier `getUnreadCount(String userId)` pour retourner `Stream<int>`
    - Implémenter `markAsRead(String notificationId)` mettant à jour `isRead` à `true` dans Firestore
    - Implémenter `markAllAsRead(String userId)` via batch Firestore
    - S'assurer que `createNotification` enregistre tous les champs requis : `userId`, `title`, `message`, `type`, `reservationId`, `isRead: false`, `createdAt`
    - _Requirements: 9.1, 9.2, 9.3, 9.6_
  - [ ]* 5.2 Écrire le test de propriété pour l'exactitude du badge (Propriété 5)
    - **Propriété 5 : Exactitude du badge de notifications**
    - **Validates: Requirements 9.4, 9.5**

- [x] 6. Créer `PdfService`
  - [x] 6.1 Créer `lib/services/pdf_service.dart`
    - Implémenter `generateConfirmationPdf(ReservationModel reservation, ResourceModel resource)` retournant `Future<Uint8List>`
    - Le PDF doit contenir : titre "FlutterBooking — Confirmation de réservation", nom de la ressource, dates/heures de début et fin, nom de l'utilisateur, statut `Confirmée`, date de validation, notes (si présentes), identifiant de réservation en pied de page
    - Utiliser les packages `pdf` et `printing` déjà présents dans `pubspec.yaml`
    - Implémenter `sharePdf(Uint8List pdfBytes, String fileName)` via `share_plus`
    - _Requirements: 11.1, 11.2, 11.3, 11.4_
  - [ ]* 6.2 Écrire le test de propriété pour le contenu du PDF (Propriété 8)
    - **Propriété 8 : Contenu du PDF de confirmation**
    - **Validates: Requirements 11.1**

- [x] 7. Créer `ICalService`
  - [x] 7.1 Créer `lib/services/ical_service.dart`
    - Implémenter `generateIcs(ReservationModel reservation)` retournant un `String` conforme RFC 5545
    - Le fichier `.ics` doit contenir : `BEGIN:VCALENDAR`, `VERSION:2.0`, `PRODID:-//FlutterBooking//FR`, `BEGIN:VEVENT`, `UID:{id}@flutterbooking`, `DTSTART`, `DTEND`, `SUMMARY`, `DESCRIPTION`, `END:VEVENT`, `END:VCALENDAR`
    - Implémenter `parseIcs(String icsContent)` retournant `Map<String, String>` des champs extraits
    - Implémenter `shareIcs(ReservationModel reservation)` via `share_plus` (écriture temporaire + partage)
    - _Requirements: 12.1, 12.2_
  - [ ]* 7.2 Écrire le test de propriété pour le round-trip iCal (Propriété 3)
    - **Propriété 3 : Round-trip iCal**
    - **Validates: Requirements 12.3**
  - [ ]* 7.3 Écrire le test de propriété pour les champs RFC 5545 (Propriété 4)
    - **Propriété 4 : Champs RFC 5545 présents dans le fichier iCal**
    - **Validates: Requirements 12.1**

- [ ] 8. Checkpoint — S'assurer que tous les tests passent
  - Vérifier que les tests unitaires et de propriétés passent, demander à l'utilisateur si des questions se posent.

- [x] 9. Enrichir les vues admin et notifications
  - [x] 9.1 Enrichir `lib/views/admin/admin_reservations_page.dart`
    - Modifier `_updateReservationStatus` pour passer `validatedBy` (nom de l'utilisateur courant via `UserAuthProvider`) à `ReservationService.validateReservation`
    - Appeler `NotificationService.createNotification` après validation/rejet pour notifier l'utilisateur concerné
    - Afficher le champ `validatedBy` dans la carte de réservation pour les statuts `confirmed` et `rejected`
    - _Requirements: 7.2, 7.3, 7.4, 7.5_
  - [x] 9.2 Enrichir `lib/views/admin/admin_dashboard_page.dart`
    - Implémenter trois `StreamBuilder` indépendants sur Firestore pour les statistiques en temps réel
    - Afficher les compteurs par statut (`pending`, `confirmed`, `cancelled`, `rejected`)
    - Afficher le top 5 des ressources les plus réservées
    - Afficher le nombre de réservations de la semaine courante et du mois courant
    - Gérer le cas où aucune réservation n'existe (afficher des zéros sans erreur)
    - _Requirements: 13.1, 13.2, 13.3, 13.4_
  - [x] 9.3 Enrichir `lib/views/notifications/notifications_page.dart`
    - Consommer `NotificationService.getUserNotifications(userId)` via `StreamBuilder<List<NotificationModel>>`
    - Afficher les notifications triées par date décroissante
    - Distinguer visuellement les notifications lues (fond neutre) et non lues (fond coloré ou opacité)
    - Au tap sur une notification non lue, appeler `NotificationService.markAsRead(notificationId)`
    - Ajouter un bouton "Tout marquer comme lu" appelant `markAllAsRead`
    - _Requirements: 9.2, 9.3_

- [x] 10. Créer le widget `NotificationBadge` et l'intégrer dans `MainShell`
  - [x] 10.1 Créer `lib/widgets/notification_badge.dart`
    - Définir `NotificationBadge` avec les paramètres `Widget child` et `int count`
    - Afficher un cercle rouge avec le nombre si `count > 0`
    - Masquer le badge si `count == 0`
    - _Requirements: 9.4, 9.5_
  - [x] 10.2 Intégrer `NotificationBadge` dans `lib/views/home/main_shell.dart`
    - Envelopper l'icône de l'onglet Notifications avec `NotificationBadge`
    - Alimenter le compteur via `StreamBuilder<int>` sur `NotificationService.getUnreadCount(userId)`
    - Récupérer le `userId` depuis `UserAuthProvider`
    - _Requirements: 9.4, 9.5, 10.4_

- [x] 11. Ajouter les boutons PDF et iCal dans `MyReservationsPage`
  - Ajouter un bouton "PDF" sur les réservations avec statut `confirmed` appelant `PdfService.generateConfirmationPdf` puis `PdfService.sharePdf`
  - Ajouter un bouton "iCal" sur les réservations avec statut `confirmed` appelant `ICalService.shareIcs`
  - Gérer les erreurs avec un `SnackBar` explicite
  - _Requirements: 11.1, 11.2, 11.3, 12.1, 12.2_

- [x] 12. Checkpoint final — S'assurer que tous les tests passent
  - Vérifier que l'ensemble des tests unitaires, de propriétés et d'intégration passent, demander à l'utilisateur si des questions se posent.

## Notes

- Les tâches marquées avec `*` sont optionnelles et peuvent être ignorées pour un MVP plus rapide
- Chaque tâche référence les requirements spécifiques pour la traçabilité
- Les checkpoints garantissent une validation incrémentale
- Les tests de propriétés valident les invariants universels (détection de conflit, round-trip iCal, badge, filtrage)
- Les tests unitaires valident les exemples concrets et les cas limites

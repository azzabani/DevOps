# Document de Requirements — FlutterBooking

## Introduction

FlutterBooking est une application mobile Flutter permettant aux utilisateurs de réserver des ressources partagées (salles de réunion, véhicules, ordinateurs et matériels divers). L'application s'appuie sur Firebase (Auth + Firestore) pour l'authentification et la persistance des données, et sur `table_calendar` pour la visualisation des disponibilités. Elle cible trois profils d'utilisateurs : utilisateur standard, manager et administrateur.

L'objectif de cette amélioration est de compléter et consolider les fonctionnalités existantes selon le cahier des charges : gestion des rôles, catalogue de ressources avec CRUD admin, réservation avec détection de conflits en temps réel, workflow de validation manager, notifications in-app, et fonctionnalités bonus (dashboard admin, PDF de confirmation, export iCal).

---

## Glossaire

- **App** : l'application mobile Flutter FlutterBooking.
- **Utilisateur** : toute personne authentifiée dans l'App, quel que soit son rôle.
- **Utilisateur_Standard** : utilisateur avec le rôle `user`, sans droits d'administration.
- **Manager** : utilisateur avec le rôle `manager`, habilité à valider ou rejeter les réservations.
- **Admin** : utilisateur avec le rôle `admin`, disposant de tous les droits (CRUD ressources, gestion des réservations, accès au dashboard).
- **Ressource** : entité réservable (salle de réunion, véhicule, ordinateur, matériel divers).
- **Réservation** : demande d'occupation d'une Ressource sur un créneau horaire défini.
- **Créneau** : plage horaire définie par une heure de début et une heure de fin le même jour.
- **Conflit** : situation où deux Réservations actives (statut `pending` ou `confirmed`) se chevauchent sur la même Ressource.
- **Statut_Réservation** : état d'une Réservation parmi `pending`, `confirmed`, `cancelled`, `rejected`.
- **Notification_InApp** : message stocké dans Firestore et affiché dans l'App, sans push externe.
- **AuthService** : service Flutter gérant l'authentification Firebase.
- **ReservationService** : service Flutter gérant les opérations CRUD sur les Réservations dans Firestore.
- **NotificationService** : service Flutter gérant la création et la lecture des Notifications_InApp.
- **ResourceProvider** : provider Flutter exposant la liste des Ressources à l'interface.
- **CalendarProvider** : provider Flutter gérant l'état du calendrier et des créneaux.
- **PDF_Service** : service Flutter générant un document PDF de confirmation de Réservation.
- **iCal_Service** : service Flutter générant un fichier `.ics` exportable.
- **Dashboard** : vue admin affichant des statistiques agrégées sur les Réservations et les Ressources.

---

## Requirements

---

### Requirement 1 : Authentification et gestion des rôles

**User Story :** En tant qu'Utilisateur, je veux pouvoir m'inscrire et me connecter avec un email et un mot de passe, afin d'accéder à l'App de manière sécurisée avec les droits correspondant à mon rôle.

#### Acceptance Criteria

1. WHEN un Utilisateur soumet un formulaire d'inscription avec un email valide et un mot de passe d'au moins 6 caractères, THE AuthService SHALL créer un compte Firebase Auth et enregistrer un document utilisateur dans Firestore avec le rôle `user` par défaut.
2. WHEN un Utilisateur soumet un formulaire de connexion avec des identifiants valides, THE AuthService SHALL authentifier l'Utilisateur et charger ses données de profil (nom, email, rôle) depuis Firestore.
3. IF un Utilisateur soumet un formulaire de connexion avec des identifiants invalides, THEN THE App SHALL afficher un message d'erreur explicite sans exposer de détails techniques.
4. WHEN un Utilisateur se déconnecte, THE AuthService SHALL terminer la session Firebase et rediriger l'Utilisateur vers la page de connexion.
5. WHILE un Utilisateur est authentifié avec le rôle `admin`, THE App SHALL afficher les menus et actions réservés à l'Admin (CRUD ressources, dashboard, validation).
6. WHILE un Utilisateur est authentifié avec le rôle `manager`, THE App SHALL afficher les actions de validation des Réservations sans accès au CRUD des Ressources.
7. WHILE un Utilisateur est authentifié avec le rôle `user`, THE App SHALL masquer toutes les actions d'administration et de validation.
8. THE AuthService SHALL exposer un stream d'état d'authentification permettant à l'App de réagir en temps réel aux changements de session.

---

### Requirement 2 : Gestion du profil utilisateur

**User Story :** En tant qu'Utilisateur, je veux pouvoir consulter et modifier mon profil, afin de maintenir mes informations à jour.

#### Acceptance Criteria

1. WHEN un Utilisateur accède à la page de profil, THE App SHALL afficher son nom, son email et son rôle actuel récupérés depuis Firestore.
2. WHEN un Utilisateur soumet un formulaire de modification de profil avec un nom non vide, THE AuthService SHALL mettre à jour le champ `name` dans Firestore et afficher un message de confirmation.
3. IF un Utilisateur tente de soumettre un nom vide, THEN THE App SHALL afficher un message de validation sans appeler Firestore.
4. THE App SHALL afficher le rôle de l'Utilisateur en lecture seule sur la page de profil.

---

### Requirement 3 : Catalogue de ressources

**User Story :** En tant qu'Utilisateur, je veux consulter la liste des Ressources disponibles filtrées par catégorie, afin de trouver rapidement la Ressource adaptée à mon besoin.

#### Acceptance Criteria

1. THE ResourceProvider SHALL charger la liste complète des Ressources depuis Firestore en temps réel via un stream.
2. WHEN un Utilisateur sélectionne un filtre de catégorie (salle, véhicule, ordinateur, matériel), THE App SHALL afficher uniquement les Ressources correspondant à cette catégorie.
3. THE App SHALL afficher pour chaque Ressource : son image (ou une image par défaut selon la catégorie), son nom, sa description, sa capacité et sa catégorie.
4. WHEN un Utilisateur sélectionne une Ressource, THE App SHALL afficher la page de détail de cette Ressource avec toutes ses informations.
5. IF aucune Ressource ne correspond au filtre sélectionné, THEN THE App SHALL afficher un message indiquant qu'aucune ressource n'est disponible dans cette catégorie.

---

### Requirement 4 : CRUD des ressources (Admin uniquement)

**User Story :** En tant qu'Admin, je veux pouvoir créer, modifier et supprimer des Ressources, afin de maintenir le catalogue à jour.

#### Acceptance Criteria

1. WHILE un Utilisateur est authentifié avec le rôle `admin`, THE App SHALL afficher les contrôles de création, modification et suppression des Ressources.
2. WHEN un Admin soumet un formulaire de création de Ressource avec un nom, une description, une catégorie et une capacité valides, THE ReservationService SHALL créer un nouveau document dans la collection `resources` de Firestore.
3. WHEN un Admin soumet un formulaire de modification d'une Ressource existante, THE ReservationService SHALL mettre à jour les champs modifiés dans Firestore.
4. WHEN un Admin confirme la suppression d'une Ressource, THE ReservationService SHALL supprimer le document correspondant dans Firestore.
5. IF un Admin tente de soumettre un formulaire de Ressource avec un nom vide ou une capacité inférieure à 1, THEN THE App SHALL afficher des messages de validation et bloquer la soumission.
6. WHILE un Utilisateur est authentifié avec le rôle `user` ou `manager`, THE App SHALL masquer les contrôles CRUD des Ressources.

---

### Requirement 5 : Vue calendrier des disponibilités

**User Story :** En tant qu'Utilisateur, je veux visualiser les créneaux disponibles et réservés d'une Ressource sur un calendrier, afin de choisir un créneau libre.

#### Acceptance Criteria

1. WHEN un Utilisateur accède à la page de réservation d'une Ressource, THE CalendarProvider SHALL charger en temps réel les Réservations actives (statut `pending` ou `confirmed`) de cette Ressource depuis Firestore.
2. THE App SHALL afficher un calendrier mensuel via `table_calendar` permettant la sélection d'un jour.
3. WHEN un Utilisateur sélectionne un jour dans le calendrier, THE App SHALL afficher la grille des créneaux horaires (de 08h00 à 17h00, par tranches d'une heure) en distinguant visuellement les créneaux disponibles et les créneaux occupés.
4. WHILE un créneau est occupé par une Réservation active, THE App SHALL afficher ce créneau avec un indicateur visuel de non-disponibilité et désactiver sa sélection.
5. THE App SHALL permettre la sélection d'une heure de début et d'une heure de fin parmi les créneaux disponibles, avec l'heure de fin strictement postérieure à l'heure de début.

---

### Requirement 6 : Création de réservation avec détection de conflits

**User Story :** En tant qu'Utilisateur, je veux créer une Réservation sur un créneau disponible, avec une vérification en temps réel des conflits, afin d'éviter les doubles réservations.

#### Acceptance Criteria

1. WHEN un Utilisateur soumet une demande de Réservation, THE ReservationService SHALL vérifier l'absence de Conflit en interrogeant Firestore avant d'écrire le document.
2. IF un Conflit est détecté lors de la soumission, THEN THE ReservationService SHALL rejeter la création et THE App SHALL afficher un message indiquant que le créneau n'est plus disponible.
3. WHEN une Réservation est créée sans Conflit, THE ReservationService SHALL enregistrer le document dans Firestore avec le statut `pending` et les champs : `resourceId`, `resourceName`, `userId`, `userName`, `startTime`, `endTime`, `status`, `notes`, `createdAt`.
4. WHEN une Réservation est créée, THE NotificationService SHALL créer une Notification_InApp pour l'Utilisateur confirmant la mise en attente de sa demande.
5. WHEN une Réservation est créée, THE NotificationService SHALL créer une Notification_InApp pour chaque Admin et Manager les informant d'une nouvelle demande à valider.
6. THE ReservationService SHALL utiliser une logique de détection de chevauchement : un Conflit existe si `startTime_nouvelle < endTime_existante AND endTime_nouvelle > startTime_existante` pour toute Réservation active de la même Ressource.

---

### Requirement 7 : Workflow de validation par un Manager

**User Story :** En tant que Manager ou Admin, je veux pouvoir valider ou rejeter les Réservations en attente, afin de contrôler l'utilisation des Ressources.

#### Acceptance Criteria

1. WHILE un Utilisateur est authentifié avec le rôle `manager` ou `admin`, THE App SHALL afficher la liste des Réservations avec le statut `pending`.
2. WHEN un Manager ou Admin valide une Réservation, THE ReservationService SHALL mettre à jour le statut à `confirmed` et enregistrer `validatedAt` et `validatedBy` dans Firestore.
3. WHEN un Manager ou Admin rejette une Réservation, THE ReservationService SHALL mettre à jour le statut à `rejected` et enregistrer `validatedAt` et `validatedBy` dans Firestore.
4. WHEN une Réservation est confirmée, THE NotificationService SHALL créer une Notification_InApp pour l'Utilisateur concerné l'informant de la confirmation.
5. WHEN une Réservation est rejetée, THE NotificationService SHALL créer une Notification_InApp pour l'Utilisateur concerné l'informant du rejet avec le nom du validateur.
6. IF une Réservation en statut `pending` est rejetée, THEN THE ReservationService SHALL libérer le créneau correspondant pour de nouvelles demandes.

---

### Requirement 8 : Annulation et modification de réservation

**User Story :** En tant qu'Utilisateur, je veux pouvoir annuler ou modifier mes Réservations, afin de gérer mes engagements de manière flexible.

#### Acceptance Criteria

1. WHEN un Utilisateur_Standard accède à la liste de ses Réservations, THE App SHALL afficher toutes ses Réservations triées par date décroissante avec leur Statut_Réservation.
2. WHEN un Utilisateur_Standard annule une Réservation avec le statut `pending` ou `confirmed`, THE ReservationService SHALL mettre à jour le statut à `cancelled` dans Firestore.
3. WHEN une Réservation est annulée par l'Utilisateur, THE NotificationService SHALL créer une Notification_InApp pour les Admins et Managers les informant de l'annulation.
4. WHEN un Utilisateur_Standard modifie une Réservation existante en soumettant un nouveau créneau, THE ReservationService SHALL vérifier l'absence de Conflit sur le nouveau créneau avant de mettre à jour le document Firestore.
5. IF un Conflit est détecté lors de la modification, THEN THE App SHALL afficher un message d'erreur et conserver la Réservation originale inchangée.
6. WHILE une Réservation a le statut `cancelled` ou `rejected`, THE App SHALL masquer les actions d'annulation et de modification pour cette Réservation.

---

### Requirement 9 : Notifications in-app

**User Story :** En tant qu'Utilisateur, je veux recevoir des notifications dans l'App pour les événements liés à mes Réservations, afin d'être informé en temps réel.

#### Acceptance Criteria

1. THE NotificationService SHALL stocker chaque Notification_InApp dans la collection `notifications` de Firestore avec les champs : `userId`, `title`, `message`, `type`, `reservationId`, `isRead`, `createdAt`.
2. WHEN un Utilisateur accède à la page de notifications, THE App SHALL afficher toutes ses Notifications_InApp triées par date décroissante, en distinguant visuellement les notifications lues et non lues.
3. WHEN un Utilisateur sélectionne une Notification_InApp non lue, THE NotificationService SHALL mettre à jour le champ `isRead` à `true` dans Firestore.
4. THE App SHALL afficher un badge numérique sur l'icône de notifications indiquant le nombre de Notifications_InApp non lues.
5. WHEN le nombre de Notifications_InApp non lues est zéro, THE App SHALL masquer le badge numérique sur l'icône de notifications.
6. THE App SHALL envoyer des Notifications_InApp pour les événements suivants : création de Réservation (à l'Utilisateur et aux Admins/Managers), confirmation (à l'Utilisateur), rejet (à l'Utilisateur), annulation (aux Admins/Managers).

---

### Requirement 10 : Architecture et gestion d'état

**User Story :** En tant que développeur, je veux que l'application suive une architecture Clean avec séparation des responsabilités, afin de faciliter la maintenance et l'évolution du code.

#### Acceptance Criteria

1. THE App SHALL organiser le code selon la structure : `lib/models/`, `lib/services/`, `lib/providers/`, `lib/views/`, `lib/widgets/`.
2. THE ResourceProvider SHALL étendre `ChangeNotifier` et exposer la liste des Ressources, le filtre de catégorie actif et les méthodes de chargement depuis Firestore.
3. THE CalendarProvider SHALL étendre `ChangeNotifier` et exposer le jour sélectionné, les créneaux occupés de la Ressource courante et les méthodes de chargement.
4. THE App SHALL utiliser `MultiProvider` en racine pour injecter `UserAuthProvider`, `ResourceProvider` et `CalendarProvider`.
5. THE App SHALL séparer la logique métier dans les services (`AuthService`, `ReservationService`, `NotificationService`) et ne pas appeler Firestore directement depuis les vues.

---

### Requirement 11 : Génération de PDF de confirmation (Bonus)

**User Story :** En tant qu'Utilisateur, je veux pouvoir générer et partager un PDF de confirmation de ma Réservation, afin d'avoir une preuve formelle de ma réservation.

#### Acceptance Criteria

1. WHEN un Utilisateur sélectionne l'option de génération de PDF pour une Réservation confirmée, THE PDF_Service SHALL générer un document PDF contenant : le nom de la Ressource, les dates et heures de début et de fin, le nom de l'Utilisateur, le statut `confirmed` et la date de validation.
2. WHEN le PDF est généré, THE App SHALL proposer à l'Utilisateur de le partager ou de l'enregistrer via le système de partage natif de l'appareil.
3. IF la génération du PDF échoue, THEN THE App SHALL afficher un message d'erreur explicite.
4. WHERE la fonctionnalité PDF est activée, THE PDF_Service SHALL utiliser le package `pdf` et `printing` déjà présents dans les dépendances.

---

### Requirement 12 : Export iCal / intégration calendrier (Bonus)

**User Story :** En tant qu'Utilisateur, je veux pouvoir exporter une Réservation confirmée au format iCal, afin de l'ajouter à mon calendrier personnel.

#### Acceptance Criteria

1. WHEN un Utilisateur sélectionne l'option d'export iCal pour une Réservation confirmée, THE iCal_Service SHALL générer un fichier `.ics` conforme à la RFC 5545 contenant : `DTSTART`, `DTEND`, `SUMMARY` (nom de la Ressource), `DESCRIPTION` (notes de la Réservation) et `UID` (identifiant unique de la Réservation).
2. WHEN le fichier `.ics` est généré, THE App SHALL proposer à l'Utilisateur de le partager via le système de partage natif de l'appareil.
3. FOR ALL Réservations confirmées exportées, parsing du fichier `.ics` généré puis re-génération SHALL produire un fichier `.ics` équivalent (propriété de round-trip).

---

### Requirement 13 : Dashboard Admin avec statistiques (Bonus)

**User Story :** En tant qu'Admin, je veux accéder à un tableau de bord avec des statistiques de réservation, afin de piloter l'utilisation des Ressources.

#### Acceptance Criteria

1. WHILE un Utilisateur est authentifié avec le rôle `admin`, THE App SHALL afficher un accès au Dashboard dans la navigation principale.
2. WHEN un Admin accède au Dashboard, THE App SHALL afficher : le nombre total de Réservations par Statut_Réservation, le nombre de Réservations par Ressource, et le nombre de Réservations par période (semaine courante, mois courant).
3. THE App SHALL mettre à jour les statistiques du Dashboard en temps réel via des streams Firestore.
4. IF aucune Réservation n'existe, THEN THE Dashboard SHALL afficher des valeurs à zéro sans erreur.

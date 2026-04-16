# 📱 FlutterBooking — SUP4 DEV

Application mobile Flutter de réservation de ressources partagées (salles de réunion, véhicules, ordinateurs, matériels divers) avec interface calendrier et gestion des rôles.

---

## 🎯 Objectif

Permettre aux utilisateurs de réserver des ressources d'entreprise via une interface intuitive avec visualisation calendrier des disponibilités, gestion des conflits en temps réel et workflow de validation par un manager.

---

## ✅ Fonctionnalités implémentées

### Authentification & Rôles
- Inscription / Connexion avec Firebase Auth
- 3 rôles : **Utilisateur**, **Manager**, **Administrateur**
- Récupération de mot de passe par email
- Gestion du profil (nom, email, mot de passe)

### Catalogue de ressources
- Liste complète avec filtre par catégorie (salle, véhicule, ordinateur, matériel)
- Filtre par capacité (slider)
- Affichage : image, nom, description, capacité
- CRUD ressources (admin uniquement)

### Réservation
- Vue calendrier des créneaux disponibles (`table_calendar`)
- Sélection d'un jour et d'un créneau horaire (08h–17h)
- Vérification des conflits en temps réel
- Workflow de validation par un manager (statut `pending` → `confirmed`)
- Annulation et modification possible par l'utilisateur
- Export PDF de confirmation
- Export iCal (.ics)

### Notifications in-app
- Confirmation de réservation
- Annulation de réservation
- Validation ou refus par un manager (avec motif)
- Badge de notifications non lues

### Espace Manager
- Liste des réservations à valider (En attente / Confirmées / Rejetées / Toutes)
- Validation avec confirmation
- Rejet avec motif optionnel

### Espace Administrateur
- Dashboard avec statistiques (total, statuts, top ressources, graphique hebdomadaire)
- CRUD complet des ressources
- Gestion des utilisateurs (liste, modification de rôle, désactivation, suppression)
- Validation des réservations

---

## 🏗️ Architecture

```
lib/
├── models/           # UserModel, ResourceModel, ReservationModel, NotificationModel
├── services/         # AuthService, ReservationService, NotificationService, PdfService, ICalService
├── providers/        # UserAuthProvider, ResourceProvider, CalendarProvider
├── views/
│   ├── auth/         # LoginPage, SignupPage
│   ├── home/         # HomePage, MainShell
│   ├── calendar/     # BookingPage, CalendarPage, MyReservationsPage, EditReservationPage
│   ├── resources/    # ResourcesPage, ResourceDetailPage
│   ├── notifications/# NotificationsPage
│   ├── profile/      # ProfilePage
│   └── admin/        # AdminPage, AdminDashboardPage, AdminResourcePage, AdminUsersPage, AdminValidatePage
├── widgets/          # NotificationBadge, CalendarWidget, ResourceCard, ReservationModal
└── main.dart
```

Architecture **Clean / MVC** avec séparation stricte : les vues ne communiquent jamais directement avec Firestore, tout passe par les services.

---

## 🛠️ Stack technique

| Technologie | Usage |
|-------------|-------|
| Flutter 3.x | Framework mobile |
| Firebase Auth | Authentification |
| Cloud Firestore | Base de données temps réel |
| Provider | Gestion d'état |
| table_calendar | Interface calendrier |
| pdf + printing | Génération PDF |
| share_plus | Partage fichiers |
| intl | Internationalisation (fr_FR) |

---

## 🚀 Installation

```bash
# 1. Cloner le projet
git clone <repo-url>
cd flutter_booking

# 2. Installer les dépendances
flutter pub get

# 3. Configurer Firebase
# → Ajouter google-services.json (Android) et GoogleService-Info.plist (iOS)
# → Ou utiliser le fichier firebase_options.dart existant

# 4. Lancer l'application
flutter run
```

---

## 🎨 Maquette

L'interface suit un design Material 3 avec :
- Navigation bottom bar (6 onglets)
- AppBar gradient bleu avec informations utilisateur
- Cards avec indicateurs de statut colorés
- Calendrier interactif avec créneaux visuels

---

## 🏆 Bonus implémentés

- ✅ Dashboard admin avec statistiques et graphiques
- ✅ PDF de confirmation (généré avec le package `pdf`)
- ✅ Export iCal / intégration calendrier (.ics RFC 5545)
- ✅ Gestion complète des utilisateurs (admin)

---

## 📊 Critères de validation

| Critère | Statut |
|---------|--------|
| UI claire et responsive | ✅ Material 3, bottom nav |
| Auth + rôles | ✅ user / manager / admin |
| Catalogue ressources | ✅ avec filtres |
| Calendrier + réservation | ✅ table_calendar |
| Gestion des conflits | ✅ temps réel |
| Notifications | ✅ in-app avec badge |
| Modification/annulation | ✅ |
| Documentation README | ✅ |

---

## 👥 Projet

**SUP4 DEV — Projet Flutter 03**  
Application de réservation de ressources — FlutterBooking

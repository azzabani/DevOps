// lib/main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_booking/firebase_options.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:flutter_booking/services/preferences_service.dart';
import 'package:flutter_booking/providers/auth_provider.dart';
import 'package:flutter_booking/providers/resource_provider.dart';
import 'package:flutter_booking/providers/calendar_provider.dart';

import 'views/auth/login_page.dart';
import 'views/auth/signup_page.dart';
import 'views/home/main_shell.dart';
import 'views/resources/resources_page.dart';
import 'views/resources/resource_detail_page.dart';
import 'views/calendar/booking_page.dart';
import 'views/calendar/calendar_page.dart';
import 'views/calendar/my_reservations_page.dart';
import 'views/calendar/edit_reservation_page.dart';
import 'views/notifications/notifications_page.dart';
import 'views/admin/admin_page.dart';
import 'models/resource_model.dart';
import 'models/reservation_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('fr_FR', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserAuthProvider()),
        ChangeNotifierProvider(create: (_) => ResourceProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
      ],
      child: MaterialApp(
        title: 'Booky',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Poppins',
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(builder: (_) => const AuthWrapper());
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginPage());
            case '/signup':
              return MaterialPageRoute(builder: (_) => const SignupPage());
            case '/home':
              return MaterialPageRoute(builder: (_) => const MainShell());
            case '/resources':
              return MaterialPageRoute(builder: (_) => const ResourcesPage());
            case '/calendar':
              return MaterialPageRoute(
                builder: (_) => const MainShell(initialIndex: 2));
            case '/my_reservations':
              return MaterialPageRoute(
                builder: (_) => const MainShell(initialIndex: 3));
            case '/notifications':
              return MaterialPageRoute(
                builder: (_) => const MainShell(initialIndex: 4));
            case '/resource_detail':
              final resource = settings.arguments as ResourceModel;
              return MaterialPageRoute(
                builder: (_) => ResourceDetailPage(resource: resource),
              );
            case '/booking':
              final resource = settings.arguments as ResourceModel;
              return MaterialPageRoute(
                builder: (_) => BookingPage(resource: resource),
              );
            case '/edit_reservation':
              final reservation = settings.arguments as ReservationModel;
              return MaterialPageRoute(
                builder: (_) => EditReservationPage(reservation: reservation),
              );
            case '/admin':
              return MaterialPageRoute(builder: (_) => const AdminPage());
            default:
              return MaterialPageRoute(builder: (_) => const AuthWrapper());
          }
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isCheckingAutoLogin = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final rememberMe = await PreferencesService.getRememberMe();
    if (rememberMe) {
      await PreferencesService.getSavedEmail();
    }
    if (mounted) {
      setState(() => _isCheckingAutoLogin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isCheckingAutoLogin) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data != null) return const MainShell();
        return const LoginPage();
      },
    );
  }
}

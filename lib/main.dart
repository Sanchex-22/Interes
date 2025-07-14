import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:interest_compound_game/screens/calculator_screen.dart';
import 'package:interest_compound_game/screens/chat_screen.dart';
import 'package:interest_compound_game/screens/progress_screen.dart';
import 'package:interest_compound_game/screens/ranking_screen.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await MobileAds.instance.initialize();
  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tu App de Interés Compuesto',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Aquí es donde verificas el estado de autenticación
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Muestra un indicador de carga mientras se verifica la autenticación
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // Si hay un usuario logueado, ve al Dashboard
            return Dashboard();
          } else {
            // Si no hay usuario logueado, ve a la pantalla de Login
            return LoginScreen();
          }
        },
      ),
      routes: {
        '/calculator': (context) => CalculatorScreen(), // Asegúrate de definir tus rutas
        '/chat': (context) => ChatScreen(),
        '/ranking': (context) => RankingScreen(),
        '/progress': (context) => ProgressScreen(),
        '/dashboard': (context) => Dashboard(),
        // ... otras rutas
      },
    );
  }
}
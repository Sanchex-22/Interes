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
      title: 'Interés Compuesto Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/dashboard': (context) => Dashboard(),
        '/calculator': (context) => CalculatorScreen(),
        '/chat': (context) => ChatScreen(),
        '/ranking': (context) => RankingScreen(), 
        '/progress': (context) => ProgressScreen(), 
      },
    );
  }
}

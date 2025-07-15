import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false; // Bandera para evitar mostrar múltiples anuncios
  DateTime? _lastAdShownTime; // Para controlar la frecuencia de los anuncios


  String get _appOpenAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ca-app-pub-2116089172655720/7019833718'; // ID de prueba de Android
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-2116089172655720/8336198081'; // ID de prueba de iOS
    }
    return ''; // Retorna vacío si no es Android ni iOS
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Añade el observador del ciclo de vida
    _loadAppOpenAd(); // Carga el primer anuncio al iniciar la aplicación
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Elimina el observador
    _appOpenAd?.dispose(); // Libera los recursos del anuncio
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Escucha los cambios en el ciclo de vida de la aplicación
    if (state == AppLifecycleState.resumed) {
      // Si la aplicación vuelve a primer plano
      if (_appOpenAd != null && !_isShowingAd) {
        // Solo muestra el anuncio si ha pasado un tiempo desde el último mostrado
        if (_lastAdShownTime == null || DateTime.now().difference(_lastAdShownTime!).inMinutes >= 1) { // Muestra cada 1 minuto
          _showAppOpenAd();
        } else {
          print('AppOpenAd: Demasiado pronto para mostrar otro anuncio.');
        }
      } else if (_appOpenAd == null) {
        // Si no hay un anuncio cargado, intenta cargarlo
        _loadAppOpenAd();
      }
    }
  }

  // Función para cargar el anuncio de apertura de aplicación
  void _loadAppOpenAd() {
    if (_appOpenAdUnitId.isEmpty) {
      print('AppOpenAd: ID de unidad de anuncio no configurado para la plataforma actual.');
      return;
    }

    AppOpenAd.load(
      adUnitId: _appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          print('AppOpenAd cargado exitosamente.');
        },
        onAdFailedToLoad: (error) {
          print('AppOpenAd falló al cargar: $error');
          _appOpenAd = null; // Asegúrate de limpiar el anuncio si falla la carga
        },
      ),
    );
  }

  // Función para mostrar el anuncio de apertura de aplicación
  void _showAppOpenAd() {
    if (_appOpenAd == null) {
      print('AppOpenAd: No hay anuncio cargado para mostrar.');
      _loadAppOpenAd(); // Intenta cargar uno nuevo
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        _lastAdShownTime = DateTime.now(); // Registra el tiempo en que se mostró el anuncio
        print('AppOpenAd mostrado en pantalla completa.');
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose(); // Libera los recursos del anuncio mostrado
        _appOpenAd = null; // Limpia la referencia
        _loadAppOpenAd(); // Carga el siguiente anuncio para la próxima vez
        print('AppOpenAd cerrado.');
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose(); // Libera los recursos del anuncio que falló
        _appOpenAd = null; // Limpia la referencia
        _loadAppOpenAd(); // Intenta cargar el siguiente anuncio
        print('AppOpenAd falló al mostrar: $error');
      },
    );
    _appOpenAd!.show();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tu App de Interés Compuesto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
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

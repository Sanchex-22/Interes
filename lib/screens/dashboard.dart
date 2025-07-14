import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa FirebaseAuth
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:interest_compound_game/screens/login_screen.dart'; // Importa Google Mobile Ads


class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance; // Instancia de FirebaseAuth
  User? _currentUser; // Para almacenar la información del usuario actual

  // Variable para el anuncio de banner
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // ID de la unidad de anuncios de prueba para banner
  // ¡IMPORTANTE! Reemplaza esto con tu ID de unidad de anuncios real de AdMob en producción.
  // Para pruebas, usa los IDs de prueba de Google:
  // Android: ca-app-pub-3940256099942544/6300978111
  // iOS: ca-app-pub-3940256099942544/2934735716
String get _adUnitId {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'ca-app-pub-3940256099942544/6300978111'; // ID de prueba de Android
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    return 'ca-app-pub-3940256099942544/2934735716'; // ID de prueba de iOS
  }
  return ''; // Retorna vacío si no es Android ni iOS
}
      
  @override
  void initState() {
    super.initState();
    _loadCurrentUser(); // Carga la información del usuario al iniciar el widget
    _loadBannerAd(); // Carga el anuncio de banner
  }

  // Función para obtener el usuario actualmente logueado
  void _loadCurrentUser() {
    setState(() {
      _currentUser = _auth.currentUser; // Obtiene el usuario de Firebase Auth
    });
  }

  // Función para cargar el anuncio de banner
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId, // Usa el ID de unidad de anuncios
      request: const AdRequest(), // Solicitud de anuncio
      size: AdSize.banner, // Tamaño del banner (320x50)
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          // Se llama cuando el anuncio se ha cargado correctamente
          setState(() {
            _isBannerAdLoaded = true;
          });
          print('BannerAd cargado.');
        },
        onAdFailedToLoad: (ad, error) {
          // Se llama cuando el anuncio no se pudo cargar
          ad.dispose(); // Libera los recursos del anuncio
          print('BannerAd falló al cargar: $error');
        },
        onAdOpened: (ad) => print('BannerAd abierto.'),
        onAdClosed: (ad) => print('BannerAd cerrado.'),
        onAdImpression: (ad) => print('BannerAd impresión.'),
      ),
    )..load(); // Inicia la carga del anuncio
  }

  // Función para cerrar la sesión del usuario
  Future<void> _logout() async {
    try {
      await _auth.signOut(); // Cierra la sesión en Firebase
      // Navega de regreso a la pantalla de login y elimina todas las rutas anteriores
      // Esto previene que el usuario regrese al dashboard con el botón de atrás
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()), // Redirige a la pantalla de Login
        (Route<dynamic> route) => false, // Elimina todas las rutas de la pila
      );
      // Muestra un mensaje de confirmación al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión cerrada correctamente')),
      );
    } catch (e) {
      // Manejo de errores en caso de que el cierre de sesión falle
      print('Error al cerrar sesión: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cerrar sesión. Inténtalo de nuevo.')),
      );
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose(); // Asegúrate de liberar los recursos del anuncio al salir del widget
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de Control')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero, // Elimina el padding por defecto del ListView para que el DrawerHeader ocupe todo el espacio superior
          children: [
            // Encabezado del Drawer que muestra la información del usuario
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.indigo, // Color de fondo del encabezado
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Alinea el contenido a la izquierda
                mainAxisAlignment: MainAxisAlignment.end, // Alinea el contenido al final del espacio disponible
                children: [
                  // Avatar del usuario (puede ser un icono por defecto o una imagen de perfil)
                  const CircleAvatar(
                    radius: 30, // Tamaño del avatar
                    backgroundColor: Colors.white, // Color de fondo del avatar
                    child: Icon(Icons.person, size: 40, color: Colors.indigo), // Icono de persona por defecto
                    // Si el usuario tuviera una foto de perfil en Firebase, podrías usar:
                    // backgroundImage: _currentUser?.photoURL != null
                    //     ? NetworkImage(_currentUser!.photoURL!)
                    //     : null,
                  ),
                  const SizedBox(height: 8), // Espacio entre el avatar y el texto
                  // Muestra el correo electrónico del usuario logueado o 'Invitado'
                  Text(
                    _currentUser?.email ?? 'Invitado', // Si _currentUser.email es nulo, muestra 'Invitado'
                    style: const TextStyle(color: Colors.white, fontSize: 18), // Estilo del texto del correo
                  ),
                  const SizedBox(height: 4), // Pequeño espacio
                  // Muestra el UID del usuario o 'No logueado'
                  Text(
                    _currentUser != null ? 'ID: ${_currentUser!.uid}' : 'No logueado',
                    style: const TextStyle(color: Colors.white70, fontSize: 12), // Estilo del texto del UID
                  ),
                ],
              ),
            ),
            // Opciones de menú existentes
            ListTile(
              title: const Text('Calculadora'),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer antes de navegar
                Navigator.pushNamed(context, '/calculator');
              },
            ),
            ListTile(
              title: const Text('Chat'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/chat');
              },
            ),
            ListTile(
              title: const Text('Ranking'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/ranking');
              },
            ),
            const Divider(), // Un divisor visual para separar las opciones principales del botón de logout
            // Botón para cerrar sesión
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red), // Icono de salida
              title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)), // Texto del botón
              onTap: _logout, // Llama a la función _logout cuando se presiona
            ),
          ],
        ),
      ),
      body: Column( // Usamos Column para apilar el texto y el anuncio
        children: [
          Expanded( // El texto ocupa el espacio restante
            child: Center(
              child: Text('Bienvenido al sistema de interés compuesto', style: TextStyle(fontSize: 18)),
            ),
          ),
          // Aquí se muestra el anuncio de banner
          if (_bannerAd != null && _isBannerAdLoaded) // Solo muestra el anuncio si se cargó correctamente
            Align(
              alignment: Alignment.bottomCenter, // Alinea el anuncio en la parte inferior
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!), // Widget que muestra el anuncio
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:interest_compound_game/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Firestore
import 'package:interest_compound_game/models/app_models.dart'; // Importa tus modelos de datos
import 'dart:async'; // Import for StreamSubscription

class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Add Firestore instance
  User? _currentUser;
  UserModel? _userProfile; // Nuevo: Para almacenar el perfil completo del usuario
  bool _isProfileLoading = true; // Nuevo: Estado de carga del perfil
  StreamSubscription? _userProfileSubscription; // Stream listener for user profile

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  bool _bannerAdInitialized = false; // Bandera para asegurar que el anuncio se carga una sola vez

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String get _adUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _setupUserProfileListener(); // Setup the real-time listener
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bannerAdInitialized) {
      _loadBannerAd();
      _bannerAdInitialized = true;
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _animationController.dispose();
    _userProfileSubscription?.cancel(); // Cancel the subscription to prevent memory leaks
    super.dispose();
  }

  // Setup real-time listener for user profile
  void _setupUserProfileListener() {
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      setState(() {
        _userProfile = null;
        _isProfileLoading = false;
      });
      print('Dashboard: No hay usuario autenticado para escuchar el perfil.');
      return;
    }

    // Cancel any existing subscription before setting up a new one
    _userProfileSubscription?.cancel();

    _userProfileSubscription = _firestore.collection('users').doc(_currentUser!.uid).snapshots().listen(
      (DocumentSnapshot<Map<String, dynamic>> userDoc) {
        if (userDoc.exists) {
          setState(() {
            _userProfile = UserModel.fromFirestore(userDoc);
            _isProfileLoading = false; // Data has arrived
          });
          print('Dashboard: Perfil de usuario actualizado en tiempo real.');
        } else {
          // If the profile doesn't exist, create one with default data
          // This logic is duplicated from LoginScreen, but acts as a fallback
          print('Dashboard: Perfil de usuario no encontrado en Firestore para ${_currentUser!.uid}. Creando uno básico.');
          final newUserModel = UserModel(
            uid: _currentUser!.uid,
            email: _currentUser!.email!,
            displayName: _currentUser!.displayName,
            registrationDate: DateTime.now(),
            lastLoginDate: DateTime.now(),
            role: 'user',
            totalCalculations: 0,
            totalScore: 0.0,
            currentStreak: 0,
            lastActivityDate: null,
          );
          _firestore.collection('users').doc(_currentUser!.uid).set(newUserModel.toFirestore()).then((_) {
            setState(() {
              _userProfile = newUserModel;
              _isProfileLoading = false;
            });
            print('Dashboard: Perfil de usuario creado exitosamente como fallback.');
          }).catchError((error) {
            print('Dashboard: Error al crear perfil de usuario como fallback: $error');
            setState(() {
              _userProfile = null;
              _isProfileLoading = false;
            });
          });
        }
      },
      onError: (error) {
        print('Dashboard: Error en el stream del perfil de usuario: $error');
        if (error is FirebaseException) {
          print('Código de error de Firebase: ${error.code}');
          print('Mensaje de error de Firebase: ${error.message}');
        }
        setState(() {
          _userProfile = null;
          _isProfileLoading = false;
        });
      },
      onDone: () {
        print('Dashboard: Stream del perfil de usuario terminado.');
      },
    );
  }

  void _loadBannerAd() {
    if (_adUnitId.isEmpty) {
      print('No se pudo determinar el ID de la unidad de anuncios para la plataforma actual.');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
          print('BannerAd cargado.');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('BannerAd falló al cargar: $error');
        },
        onAdOpened: (ad) => print('BannerAd abierto.'),
        onAdClosed: (ad) => print('BannerAd cerrado.'),
        onAdImpression: (ad) => print('BannerAd impresión.'),
      ),
    )..load();
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (Route<dynamic> route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sesión cerrada correctamente'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      print('Error al cerrar sesión: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cerrar sesión. Inténtalo de nuevo.'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4, // Reducido de 8 a 4
      shadowColor: color.withOpacity(0.2), // Sombra más sutil
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Reducido de 15 a 12
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12), // Reducido de 15 a 12
        child: Container(
          padding: EdgeInsets.all(10), // Reducido de 12 a 10
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12), // Reducido de 15 a 12
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 45, // Reducido de 50 a 45
                height: 45, // Reducido de 50 a 45
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2), // Sombra más sutil
                      blurRadius: 8, // Reducido de 10 a 8
                      offset: Offset(0, 4), // Ajustado el offset de la sombra
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24), // Reducido de 28 a 24
              ),
              SizedBox(height: 8), // Reducido de 10 a 8
              Text(
                title,
                style: TextStyle(
                  fontSize: 14, // Reducido de 16 a 14
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4), // Reducido de 6 a 4
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10, // Reducido de 12 a 10
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para mostrar estadísticas compactas estilo juego
  Widget _buildCompactStatDisplay({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Padding más compacto
      decoration: BoxDecoration(
        color: color.withOpacity(0.15), // Fondo sutil
        borderRadius: BorderRadius.circular(20), // Bordes redondeados
        border: Border.all(color: color.withOpacity(0.3), width: 1), // Borde ligero
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Ajusta al contenido
        children: [
          Icon(icon, color: color, size: 18), // Icono más pequeño
          SizedBox(width: 6), // Espacio entre icono y texto
          Text(
            value,
            style: TextStyle(
              fontSize: 16, // Tamaño de fuente para el valor
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Panel de Control',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF1E3A8A),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(Icons.person, size: 40, color: Color(0xFF1E3A8A)),
                    ),
                    SizedBox(height: 12),
                    Text(
                      _currentUser?.email ?? 'Invitado',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _currentUser != null ? 'ID: ${_currentUser!.uid.substring(0, 8)}...' : 'No logueado',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDrawerItem(Icons.calculate, 'Calculadora', '/calculator'),
              _buildDrawerItem(Icons.chat, 'Chat', '/chat'),
              _buildDrawerItem(Icons.leaderboard, 'Ranking', '/ranking'),
              _buildDrawerItem(Icons.trending_up, 'Progreso', '/progress'), // Añadido el item de progreso al drawer
              Divider(color: Colors.white30, thickness: 1),
              ListTile(
                leading: Icon(Icons.exit_to_app, color: Colors.white),
                title: Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Header con gradiente
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, 0, 24, 20), // Padding inferior reducido
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Hola, ${_currentUser?.email?.split('@')[0] ?? 'Usuario'}!',
                    style: TextStyle(
                      fontSize: 20, // Reducido de 24 a 20
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16), // Espacio reducido
                  // NUEVO: Estadísticas compactas estilo juego
                  _isProfileLoading
                      ? Center(child: CircularProgressIndicator(color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribuye el espacio uniformemente
                          children: [
                            _buildCompactStatDisplay(
                              icon: Icons.calculate,
                              value: '${_userProfile?.totalCalculations ?? 0} Cálculos',
                              color: Colors.amber.shade300, // Color ajustado
                            ),
                            _buildCompactStatDisplay(
                              icon: Icons.local_fire_department,
                              value: '${_userProfile?.currentStreak ?? 0} Días de Racha',
                              color: Colors.redAccent.shade200, // Color ajustado
                            ),
                          ],
                        ),
                ],
              ),
            ),

            // Grid de características
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16), // Mantenido en 16
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12, // Mantenido en 12
                  mainAxisSpacing: 12, // Mantenido en 12
                  children: [
                    _buildFeatureCard(
                      icon: Icons.calculate,
                      title: 'Calculadora',
                      subtitle: 'Calcula interés compuesto',
                      color: Colors.blue,
                      onTap: () => Navigator.pushNamed(context, '/calculator'),
                    ),
                    _buildFeatureCard(
                      icon: Icons.chat_bubble,
                      title: 'Chat',
                      subtitle: 'Conversa con otros usuarios',
                      color: Colors.green,
                      onTap: () => Navigator.pushNamed(context, '/chat'),
                    ),
                    _buildFeatureCard(
                      icon: Icons.leaderboard,
                      title: 'Ranking',
                      subtitle: 'Ve tu posición',
                      color: Colors.orange,
                      onTap: () => Navigator.pushNamed(context, '/ranking'),
                    ),
                    _buildFeatureCard(
                      icon: Icons.trending_up,
                      title: 'Progreso',
                      subtitle: 'Sigue tu avance',
                      color: Colors.purple,
                      onTap: () => Navigator.pushNamed(context, '/progress'),
                    ),
                  ],
                ),
              ),
            ),

            // Anuncio
            if (_bannerAd != null && _isBannerAdLoaded)
              Container(
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }
}

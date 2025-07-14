import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Firestore
import 'package:interest_compound_game/models/app_models.dart'; // Importa tus modelos de datos
import 'dart:math' as math;

class ProgressScreen extends StatefulWidget {
  @override
  _ProgressScreenState createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with TickerProviderStateMixin {
  // Instancias de Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Datos del progreso del usuario (ahora cargados de Firestore)
  UserModel? _userProfile;
  bool _isLoading = true; // Para mostrar un indicador de carga

  // Metas fijas para el progreso circular (pueden ser configurables en el futuro)
  final int _targetRounds = 25; // Meta de cálculos para el progreso general
  
  // Fechas y tiempo (actualmente fijas, no de Firestore)
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _targetDate = DateTime.now().add(Duration(days: 15));
  
  late AnimationController _animationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fetchUserProgress(); // Llama a la función para cargar los datos del usuario

    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _progressAnimationController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // La animación del progreso se inicializará después de cargar los datos
    // y se actualizará en _fetchUserProgress o didUpdateWidget
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.0).animate( // Inicialmente 0.0
      CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeOutCubic),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    _animationController.forward();
    // _progressAnimationController.forward() se llamará después de cargar los datos
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  // Función para cargar el progreso del usuario desde Firestore
  Future<void> _fetchUserProgress() async {
    setState(() {
      _isLoading = true;
    });

    final user = _auth.currentUser;
    if (user == null) {
      // Si no hay usuario logueado, no podemos cargar el progreso
      setState(() {
        _userProfile = null;
        _isLoading = false;
      });
      print('Progreso: No hay usuario autenticado.');
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _userProfile = UserModel.fromFirestore(userDoc);
          // Actualiza el valor final de la animación de progreso con los datos cargados
          _progressAnimation = Tween<double>(
            begin: _progressAnimation.value, // Inicia desde el valor actual
            end: (_userProfile!.totalCalculations / _targetRounds).clamp(0.0, 1.0),
          ).animate(
            CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeOutCubic),
          );
          _progressAnimationController.forward(from: 0.0); // Reinicia la animación
        });
      } else {
        // Esto no debería ocurrir si LoginScreen crea el perfil, pero es un fallback
        print('Progreso: Documento de usuario no encontrado en Firestore.');
        setState(() {
          _userProfile = null; // Asegura que el perfil sea nulo si no existe
        });
      }
    } on FirebaseException catch (e) {
      print('Progreso: Error de Firestore al cargar el perfil: ${e.code} - ${e.message}');
      // Mostrar un SnackBar o mensaje de error al usuario
    } catch (e) {
      print('Progreso: Error desconocido al cargar el perfil: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Getters para los datos del progreso
  int get _currentRounds => _userProfile?.totalCalculations ?? 0;
  int get _totalPoints => _userProfile?.totalScore.toInt() ?? 0; // Convertir a int
  int get _streak => _userProfile?.currentStreak ?? 0;

  // Calculados (no de Firestore directamente)
  int get _remainingRounds => math.max(0, _targetRounds - _currentRounds);
  int get _daysRemaining => _targetDate.difference(DateTime.now()).inDays;
  // Eliminado: double get _progressPercentage => (_currentRounds / _targetRounds) * 100; // Esto era código muerto
  // _dailyProgress y _completedToday se eliminan o se redefinen si se implementa lógica diaria

  Widget _buildProgressCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    Widget? customContent,
  }) {
    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (customContent != null) customContent else
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularProgress() {
    // Asegúrate de que _userProfile no sea nulo antes de calcular el progreso
    double currentProgress = (_userProfile?.totalCalculations ?? 0) / _targetRounds;
    currentProgress = currentProgress.clamp(0.0, 1.0); // Asegura que esté entre 0 y 1

    // Reinicia la animación cada vez que el progreso cambia
    if (_progressAnimationController.isCompleted || _progressAnimation.value != currentProgress) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value, // Inicia desde el valor actual
        end: currentProgress,
      ).animate(
        CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeOutCubic),
      );
      _progressAnimationController.forward(from: 0.0);
    }

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Círculo de fondo
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
              ),
              // Círculo de progreso
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: _progressAnimation.value,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                ),
              ),
              // Contenido central
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(currentProgress * 100).toInt()}%', // Usa currentProgress directamente
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  Text(
                    'Completado',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '$_currentRounds / $_targetRounds',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStreakIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Centrar la racha
      children: [
        Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
        SizedBox(width: 8),
        Text(
          '$_streak días',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        SizedBox(width: 8),
        Text(
          'de racha',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Mi Progreso',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))) // Muestra carga
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header con progreso circular
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF1E3A8A).withOpacity(0.3),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Tu Progreso General',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 24),
                            _buildCircularProgress(), // Usa el progreso de Firestore
                            SizedBox(height: 24),
                            _buildStreakIndicator(), // Usa la racha de Firestore
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Grid de estadísticas
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildProgressCard(
                          title: 'Vueltas Restantes',
                          value: '$_remainingRounds',
                          subtitle: 'Para alcanzar tu meta',
                          icon: Icons.flag,
                          color: Colors.orange,
                        ),
                        _buildProgressCard(
                          title: 'Días Restantes',
                          value: '$_daysRemaining',
                          subtitle: 'Hasta la fecha límite',
                          icon: Icons.calendar_today,
                          color: Colors.red,
                        ),
                        _buildProgressCard(
                          title: 'Nivel Actual',
                          value: 'N/A', // El nivel no está en el modelo actual
                          subtitle: 'Sigue así para subir',
                          icon: Icons.star,
                          color: Colors.purple,
                        ),
                        _buildProgressCard(
                          title: 'Puntos Totales',
                          value: '$_totalPoints', // Usa puntos de Firestore
                          subtitle: 'Puntos acumulados',
                          icon: Icons.emoji_events,
                          color: Colors.amber,
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Nota: Se eliminó _buildDailyProgressBar ya que requiere lógica diaria más compleja
                    // y no está directamente en el modelo de usuario actual.
                    
                    // Botón de acción (se eliminó la simulación local)
                    Container(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Este botón ya no simula el progreso localmente.
                          // El progreso se actualiza desde la CalculatorScreen.
                          // Aquí podrías, por ejemplo, navegar a la calculadora.
                          Navigator.pushNamed(context, '/calculator');
                        },
                        icon: Icon(Icons.play_arrow, color: Colors.white),
                        label: Text(
                          'Ir a la Calculadora', // Texto actualizado
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          elevation: 8,
                          shadowColor: Colors.green.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
  }
}

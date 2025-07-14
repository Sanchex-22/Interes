import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:interest_compound_game/models/app_models.dart'; // Asegúrate de que este archivo exista y contenga UserModel
import 'dart:math' as math;
import 'package:intl/intl.dart'; // Para formatear la fecha

// Definición del modelo para una entrada de meta diaria
class DailyGoalEntry {
  final int round;
  final double goalAmount;
  double currentAmount; // Puede ser modificado por el usuario
  final String suggestion;
  bool completed; // Puede ser modificado por el usuario

  DailyGoalEntry({
    required this.round,
    required this.goalAmount,
    required this.currentAmount,
    required this.suggestion,
    required this.completed,
  });

  // Constructor para crear una DailyGoalEntry desde un mapa de Firestore
  factory DailyGoalEntry.fromFirestore(Map<String, dynamic> data) {
    return DailyGoalEntry(
      round: data['round'] as int,
      goalAmount: (data['goalAmount'] as num).toDouble(),
      currentAmount: (data['currentAmount'] as num).toDouble(),
      suggestion: data['suggestion'] as String,
      completed: data['completed'] as bool,
    );
  }

  // Método para convertir la DailyGoalEntry a un mapa para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'round': round,
      'goalAmount': goalAmount,
      'currentAmount': currentAmount,
      'suggestion': suggestion,
      'completed': completed,
    };
  }
}

class ProgressScreen extends StatefulWidget {
  @override
  _ProgressScreenState createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _userProfile;
  bool _isLoading = true;
  
  final int _targetRounds = 25; // Este es un objetivo global, no directamente ligado a las metas diarias de la tabla
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _targetDate = DateTime.now().add(Duration(days: 15));
  
  late AnimationController _animationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _scaleAnimation;

  // Lista de metas diarias, ahora de tipo DailyGoalEntry
  List<DailyGoalEntry> _dailyGoals = [];

  // Mapa para almacenar los TextEditingController por índice de meta
  final Map<int, TextEditingController> _controllers = {};

  // Metas diarias predefinidas (usadas para inicializar si no hay datos para hoy)
  final List<Map<String, dynamic>> _predefinedDailyGoals = [
    {'round': 1, 'goal': 20.00, 'suggestion': 'Vende café o empanadas'},
    {'round': 2, 'goal': 40.00, 'suggestion': 'Revende cargadores o accesorios'},
    {'round': 3, 'goal': 80.00, 'suggestion': 'Haz trabajos rápidos por encargo'},
    {'round': 4, 'goal': 160.00, 'suggestion': 'Ofrece clases o tutorías'},
    {'round': 5, 'goal': 320.00, 'suggestion': 'Vende productos por catálogo'},
    {'round': 6, 'goal': 640.00, 'suggestion': 'Crea diseños o currículums'},
    {'round': 7, 'goal': 1280.00, 'suggestion': 'Revende ropa usada o reacondicionada'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserProgress(); // Carga el perfil del usuario (para racha, etc.)
    _fetchDailyGoals();   // Carga o inicializa las metas diarias del día

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
    
    // La animación de progreso se inicializará y actualizará en _fetchDailyGoals
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeOutCubic),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressAnimationController.dispose();
    // Disponer todos los TextEditingController para evitar fugas de memoria
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _fetchUserProgress() async {
    setState(() {
      _isLoading = true;
    });

    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _userProfile = null;
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _userProfile = UserModel.fromFirestore(userDoc);
          // La animación de progreso ahora se gestiona en _fetchDailyGoals
        });
      } else {
        setState(() {
          _userProfile = null;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
    } finally {
      // _isLoading se establece en false después de que _fetchDailyGoals también haya terminado
    }
  }

  // Función para cargar o inicializar las metas diarias desde Firestore
  Future<void> _fetchDailyGoals() async {
    setState(() {
      _isLoading = true;
    });

    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _dailyGoals = [];
        _isLoading = false;
      });
      return;
    }

    final todayFormatted = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyGoalsDocRef = _firestore.collection('users').doc(user.uid).collection('dailyGoals').doc(todayFormatted);

    try {
      final docSnapshot = await dailyGoalsDocRef.get();

      if (docSnapshot.exists && docSnapshot.data() != null && docSnapshot.data()!.containsKey('entries')) {
        // Si el documento para hoy existe, carga las metas
        final List<dynamic> entriesData = docSnapshot.data()!['entries'];
        setState(() {
          _dailyGoals = entriesData.map((e) => DailyGoalEntry.fromFirestore(e as Map<String, dynamic>)).toList();
          // Inicializar controladores para las metas cargadas
          _controllers.clear(); // Limpiar controladores antiguos
          for (int i = 0; i < _dailyGoals.length; i++) {
            _controllers[i] = TextEditingController(
              text: _dailyGoals[i].currentAmount > 0 ? _dailyGoals[i].currentAmount.toStringAsFixed(2) : ''
            );
          }
          // Actualizar la animación de progreso con los datos diarios
          _updateProgressAnimation();
        });
        print('Metas diarias cargadas para hoy: $todayFormatted');
      } else {
        // Si el documento para hoy no existe, inicializa y guarda las metas predefinidas
        print('No se encontraron metas diarias para hoy. Inicializando para $todayFormatted.');
        final List<DailyGoalEntry> initialGoals = _predefinedDailyGoals.map((goalData) {
          return DailyGoalEntry(
            round: goalData['round'],
            goalAmount: goalData['goal'],
            currentAmount: 0.0, // Reinicia el progreso diario
            suggestion: goalData['suggestion'],
            completed: false, // Reinicia el estado de completado
          );
        }).toList();

        await dailyGoalsDocRef.set({
          'date': Timestamp.fromDate(DateTime.now()),
          'entries': initialGoals.map((e) => e.toFirestore()).toList(),
        });

        setState(() {
          _dailyGoals = initialGoals;
          // Inicializar controladores para las metas recién creadas
          _controllers.clear();
          for (int i = 0; i < _dailyGoals.length; i++) {
            _controllers[i] = TextEditingController(
              text: _dailyGoals[i].currentAmount > 0 ? _dailyGoals[i].currentAmount.toStringAsFixed(2) : ''
            );
          }
          // Actualizar la animación de progreso con los datos diarios
          _updateProgressAnimation();
        });
        print('Metas diarias inicializadas y guardadas para hoy: $todayFormatted');
      }
    } on FirebaseException catch (e) {
      print('Firestore Error (fetchDailyGoals): ${e.code} - ${e.message}');
      // Puedes mostrar un SnackBar aquí si lo deseas
    } catch (e) {
      print('Error desconocido al cargar/inicializar metas diarias: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Función para actualizar una entrada de meta diaria en Firestore
  Future<void> _updateDailyGoalEntry(int index) async {
    final user = _auth.currentUser;
    if (user == null || _dailyGoals.isEmpty || index >= _dailyGoals.length) return;

    final todayFormatted = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyGoalsDocRef = _firestore.collection('users').doc(user.uid).collection('dailyGoals').doc(todayFormatted);

    try {
      // Actualiza solo la entrada específica en la lista local
      // y luego guarda toda la lista actualizada en Firestore.
      await dailyGoalsDocRef.update({
        'entries': _dailyGoals.map((e) => e.toFirestore()).toList(),
      });
      print('Progreso de meta diaria actualizado en Firestore para la vuelta ${index + 1}.');
      
      // Lógica para actualizar la racha si todas las metas del día están completas
      if (_currentDailyRoundsCompleted == _dailyGoals.length) {
        await _updateUserStreakAndRanking();
      }

      // Actualizar la animación de progreso después de guardar
      _updateProgressAnimation();
    } on FirebaseException catch (e) {
      print('Firestore Error (updateDailyGoalEntry): ${e.code} - ${e.message}');
      _showSnackBar('Error al actualizar la meta diaria: ${e.message}', backgroundColor: Colors.red);
    } catch (e) {
      print('Error desconocido al actualizar meta diaria: $e');
      _showSnackBar('Error desconocido al actualizar la meta diaria.', backgroundColor: Colors.red);
    }
  }

  // NUEVO: Función para actualizar la racha del usuario y el ranking
  Future<void> _updateUserStreakAndRanking() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDocRef = _firestore.collection('users').doc(user.uid);
    final rankingDocRef = _firestore.collection('rankings').doc(user.uid);

    try {
      final userSnapshot = await userDocRef.get();
      if (!userSnapshot.exists) {
        print('User profile not found for streak update.');
        return;
      }

      final currentUserModel = UserModel.fromFirestore(userSnapshot);
      int newStreak = currentUserModel.currentStreak;
      DateTime? lastActivity = currentUserModel.lastActivityDate?.toLocal(); // Convertir a hora local

      final now = DateTime.now().toLocal(); // Hora local actual
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = DateTime(now.year, now.month, now.day - 1);

      // Si la última actividad fue ayer, la racha continúa
      if (lastActivity != null && lastActivity.year == yesterday.year && lastActivity.month == yesterday.month && lastActivity.day == yesterday.day) {
        newStreak++;
        print('Racha continuada: $newStreak días');
      } 
      // Si la última actividad no fue hoy y no fue ayer, la racha se reinicia o empieza
      else if (lastActivity == null || !(lastActivity.year == today.year && lastActivity.month == today.month && lastActivity.day == today.day)) {
        newStreak = 1; // Inicia una nueva racha
        print('Nueva racha iniciada: $newStreak día');
      } else {
        // La racha ya fue actualizada hoy, no hacer nada
        print('Racha ya actualizada hoy.');
        return;
      }

      // Actualizar UserModel
      await userDocRef.update({
        'currentStreak': newStreak,
        'lastActivityDate': Timestamp.fromDate(now), // Actualizar la fecha de última actividad a hoy
      });
      print('UserModel actualizado con nueva racha: $newStreak');

      // Actualizar RankingModel
      // Primero, obtener el nombre de usuario del UserModel o usar un fallback
      String userName = currentUserModel.displayName ?? user.email ?? 'Usuario Anónimo';
      double bestScore = currentUserModel.totalScore; // Asume que totalScore es el bestScore para el ranking

      await rankingDocRef.set({
        'userId': user.uid,
        'userName': userName,
        'bestScore': bestScore,
        'lastUpdated': Timestamp.fromDate(now),
        'currentStreak': newStreak,
      }, SetOptions(merge: true)); // Usa merge para no sobrescribir todo el documento
      print('RankingModel actualizado con nueva racha: $newStreak');

      // Actualizar el estado local para que la UI se refresque
      setState(() {
        _userProfile = currentUserModel.copyWith(
          currentStreak: newStreak,
          lastActivityDate: now,
        );
      });
      _showSnackBar('¡Felicidades! Racha actualizada a $newStreak días.', backgroundColor: Colors.green);

    } on FirebaseException catch (e) {
      print('Firestore Error (updateUserStreakAndRanking): ${e.code} - ${e.message}');
      _showSnackBar('Error al actualizar la racha: ${e.message}', backgroundColor: Colors.red);
    } catch (e) {
      print('Error desconocido al actualizar racha: $e');
      _showSnackBar('Error desconocido al actualizar la racha.', backgroundColor: Colors.red);
    }
  }


  // Función para mostrar mensajes de SnackBar (para errores y éxitos)
  void _showSnackBar(String message, {Color? backgroundColor, Duration duration = const Duration(seconds: 4)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: duration,
      ),
    );
  }

  // Función para actualizar la animación de progreso
  void _updateProgressAnimation() {
    // El progreso se basa en el número de metas diarias marcadas como completadas
    final double currentProgressValue = (_currentDailyRoundsCompleted / (_dailyGoals.isEmpty ? 1 : _dailyGoals.length)).clamp(0.0, 1.0);
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: currentProgressValue,
    ).animate(
      CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeOutCubic),
    );
    _progressAnimationController.forward(from: 0.0);
  }

  // Getters para el progreso diario
  // MODIFICADO: Ahora cuenta las metas donde 'completed' es true
  int get _currentDailyRoundsCompleted {
    return _dailyGoals.where((entry) => entry.completed == true).length;
  }

  double get _currentDailyAmountAchieved {
    return _dailyGoals.fold(0.0, (sum, entry) => sum + entry.currentAmount);
  }

  // Getters existentes, ajustados para reflejar la nueva lógica de visualización
  // La racha sigue siendo una métrica global del perfil de usuario
  int get _streak => _userProfile?.currentStreak ?? 0; 
  
  // Los "puntos" ahora reflejan el monto total logrado en las metas diarias
  int get _totalPointsDisplay => _currentDailyAmountAchieved.toInt(); 

  // Las "rondas restantes" ahora reflejan las metas diarias restantes
  int get _remainingDailyGoalsCount => math.max(0, _dailyGoals.length - _currentDailyRoundsCompleted);
  
  // Los días restantes para la meta global (si aplica)
  int get _daysRemaining => _targetDate.difference(DateTime.now()).inDays;


  Widget _buildCompactProgressCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress() {
    double currentProgress = (_currentDailyRoundsCompleted / (_dailyGoals.isEmpty ? 1 : _dailyGoals.length));
    currentProgress = currentProgress.clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: _progressAnimation.value,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(currentProgress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  Text(
                    '$_currentDailyRoundsCompleted/${_dailyGoals.length}', // Muestra el progreso diario
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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

  Widget _buildDailyTrackingTable() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Seguimiento Diario de Metas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Table Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(flex: 1, child: Text('Vuelta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('Meta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('Lo que llevo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('Me falta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 3, child: Text('Idea sugerida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 1, child: Text('¿Completado?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
              ],
            ),
          ),
          // Table Rows
          ...List.generate(_dailyGoals.length, (index) {
            final goalEntry = _dailyGoals[index];
            final missing = goalEntry.goalAmount - goalEntry.currentAmount;
            
            // Obtener o crear el controlador para esta fila
            final controller = _controllers.putIfAbsent(
              index, () => TextEditingController(
                text: goalEntry.currentAmount > 0 ? goalEntry.currentAmount.toStringAsFixed(2) : ''
              )
            );

            // Asegurarse de que el texto del controlador esté sincronizado con el modelo
            // Solo actualizar si el texto actual del controlador es diferente
            if (controller.text != (goalEntry.currentAmount > 0 ? goalEntry.currentAmount.toStringAsFixed(2) : '')) {
              controller.text = goalEntry.currentAmount > 0 ? goalEntry.currentAmount.toStringAsFixed(2) : '';
              // Mover el cursor al final para una mejor experiencia de usuario
              controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
            }
            
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${goalEntry.round}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${goalEntry.goalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 28,
                      child: TextField(
                        controller: controller, // Usar el controlador persistente
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          hintText: '\$0.00',
                          hintStyle: TextStyle(fontSize: 10),
                        ),
                        style: TextStyle(fontSize: 11),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          // Actualizar el modelo de datos localmente
                          goalEntry.currentAmount = double.tryParse(value) ?? 0.0;
                          // Guardar el cambio en Firestore
                          _updateDailyGoalEntry(index); 
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${missing.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      goalEntry.suggestion,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Checkbox(
                      value: goalEntry.completed,
                      onChanged: (value) {
                        // VALIDACIÓN AÑADIDA: Solo permite marcar como completado si currentAmount >= goalAmount
                        if (value == true && goalEntry.currentAmount < goalEntry.goalAmount) {
                          _showSnackBar(
                            'Debes alcanzar o superar la meta de \$${goalEntry.goalAmount.toStringAsFixed(2)} para marcarla como completada.',
                            backgroundColor: Colors.orange,
                          );
                          // No actualiza el estado si la condición no se cumple
                          return; 
                        }
                        setState(() {
                          goalEntry.completed = value ?? false;
                        });
                        _updateDailyGoalEntry(index); // Guardar cambio en Firestore
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            );
          }),
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
          'Mi Progreso',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
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
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, size: 20),
            onPressed: () => Navigator.pushNamed(context, '/chat'),
            tooltip: 'Chat',
          ),
          IconButton(
            icon: Icon(Icons.leaderboard_outlined, size: 20),
            onPressed: () => Navigator.pushNamed(context, '/ranking'),
            tooltip: 'Ranking',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Compact Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildCircularProgress(),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Progreso General', // Este título ahora se refiere al progreso diario
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _buildCompactProgressCard(
                                      title: 'Racha',
                                      value: '$_streak días', // La racha sigue siendo global
                                      icon: Icons.local_fire_department,
                                      color: Colors.orange,
                                    ),
                                    _buildCompactProgressCard(
                                      title: 'Puntos',
                                      value: '\$${_totalPointsDisplay.toStringAsFixed(0)}', // Puntos de metas diarias
                                      icon: Icons.emoji_events,
                                      color: Colors.amber,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Daily Tracking Table
                    _buildDailyTrackingTable(),
                    
                    SizedBox(height: 20),
                    
                    // Quick Stats
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.flag, color: Colors.orange, size: 24),
                                  SizedBox(height: 4),
                                  Text(
                                    '$_remainingDailyGoalsCount', // Metas diarias restantes
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  Text(
                                    'Metas restantes', // Título ajustado
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.red, size: 24),
                                  SizedBox(height: 4),
                                  Text(
                                    '$_daysRemaining',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  Text(
                                    'Días límite',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Action Button
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/calculator');
                          },
                          icon: Icon(Icons.calculate, color: Colors.white, size: 20),
                          label: Text(
                            'Ir a la Calculadora',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            elevation: 6,
                            shadowColor: Colors.green.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
  }
}

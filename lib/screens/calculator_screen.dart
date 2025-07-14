import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Firestore
import 'package:interest_compound_game/models/app_models.dart'; // Importa tus modelos de datos

class CalculatorScreen extends StatefulWidget {
  @override
  _CalculatorScreenState createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final formatter = NumberFormat.currency(symbol: '\$');
  double _capital = 0.0;
  double _rate = 0.0;
  int _rounds = 0;
  double _result = 0.0;
  bool _showResult = false;

  late AnimationController _animationController;
  late AnimationController _resultAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance; // Instancia de Auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Instancia de Firestore

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _resultAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _resultAnimationController, curve: Curves.elasticOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _resultAnimationController.dispose();
    super.dispose();
  }

  // Función para mostrar mensajes de SnackBar
  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Lógica para calcular y guardar
  void _calculate() async { // Convertido a async
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      double total = _capital;
      for (int i = 0; i < _rounds; i++) {
        total *= (1 + (_rate / 100));
      }
      
      // Calcular la ganancia para la puntuación
      double gain = total - _capital;
      // Puedes definir una lógica de puntuación más compleja aquí
      // Por ejemplo, la puntuación podría ser la ganancia / 100 o un valor fijo por cálculo
      double scoreAchieved = gain / 10; // Ejemplo: 10% de la ganancia como puntuación

      setState(() {
        _result = total;
        _showResult = true;
      });
      _resultAnimationController.forward();

      // --- Lógica de guardado en Firestore ---
      final user = _auth.currentUser;
      if (user == null) {
        _showSnackBar('Debes iniciar sesión para guardar tu progreso.', backgroundColor: Colors.red);
        return;
      }

      try {
        // 1. Guardar el cálculo individual
        final newCalculation = CalculationModel(
          id: _firestore.collection('calculations').doc().id, // Genera un nuevo ID
          userId: user.uid,
          calculationType: 'interes_compuesto', // O podrías tener un campo para esto
          initialAmount: _capital,
          interestRate: _rate,
          timePeriod: _rounds.toDouble(),
          finalResult: _result,
          scoreAchieved: scoreAchieved,
          timestamp: DateTime.now(),
        );
        await _firestore.collection('calculations').add(newCalculation.toFirestore());
        print('Cálculo guardado en Firestore.');

        // 2. Actualizar el progreso del usuario (users collection)
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final userSnapshot = await userDocRef.get();
        UserModel currentUserModel = UserModel.fromFirestore(userSnapshot); // Obtiene el modelo actual

        // Lógica de racha
        int updatedStreak = currentUserModel.currentStreak;
        DateTime? lastActivity = currentUserModel.lastActivityDate;
        DateTime today = DateTime.now();
        DateTime yesterday = today.subtract(const Duration(days: 1));

        if (lastActivity == null || lastActivity.isBefore(yesterday.copyWith(hour: 0, minute: 0, second: 0))) {
          // Si no hay actividad previa o la última actividad fue antes de ayer, reinicia la racha
          updatedStreak = 1;
        } else if (lastActivity.isBefore(today.copyWith(hour: 0, minute: 0, second: 0))) {
          // Si la última actividad fue ayer, incrementa la racha
          updatedStreak++;
        }
        // Si la última actividad fue hoy, la racha no cambia (ya se contó)

        final Map<String, dynamic> userUpdates = {
          "totalCalculations": FieldValue.increment(1), // Incrementa en 1
          "totalScore": FieldValue.increment(scoreAchieved), // Suma la puntuación
          "currentStreak": updatedStreak,
          "lastActivityDate": Timestamp.fromDate(today), // Actualiza la fecha de última actividad
          "lastLoginDate": Timestamp.fromDate(today), // También actualiza el último login
        };
        await userDocRef.update(userUpdates);
        print('Progreso del usuario actualizado en Firestore.');

        // 3. Actualizar el ranking (rankings collection)
        final rankingDocRef = _firestore.collection('rankings').doc(user.uid);
        final rankingSnapshot = await rankingDocRef.get();
        
        double currentBestScore = (rankingSnapshot.data()?['bestScore'] as num?)?.toDouble() ?? 0.0;
        double updatedAverageScore = (currentUserModel.totalScore + scoreAchieved) / (currentUserModel.totalCalculations + 1);

        // Solo actualiza bestScore si la nueva puntuación es mayor
        if (scoreAchieved > currentBestScore) {
          currentBestScore = scoreAchieved;
        }

        final Map<String, dynamic> rankingUpdates = {
          "userName": currentUserModel.displayName ?? user.email!, // Nombre para mostrar en el ranking
          "bestScore": currentBestScore,
          "lastUpdated": Timestamp.fromDate(DateTime.now()),
          "averageScore": updatedAverageScore,
          "totalCalculations": FieldValue.increment(1), // Incrementa en 1
        };
        await rankingDocRef.set(rankingUpdates, SetOptions(merge: true)); // Usa set con merge para crear o actualizar
        print('Ranking del usuario actualizado en Firestore.');

        _showSnackBar('Cálculo y progreso guardados exitosamente!', backgroundColor: Colors.green);

      } on FirebaseException catch (e) {
        print('Firestore Error (CalculatorScreen): Código: ${e.code}, Mensaje: ${e.message}');
        _showSnackBar('Error al guardar el cálculo: ${e.message}', backgroundColor: Colors.red);
      } catch (e) {
        print('Error desconocido al guardar el cálculo: $e');
        _showSnackBar('Error desconocido al guardar el cálculo.', backgroundColor: Colors.red);
      }
    }
  }

  void _reset() {
    setState(() {
      _showResult = false;
      _result = 0.0;
    });
    _resultAnimationController.reset();
    _formKey.currentState?.reset();
  }

  Widget _buildInputCard({
    required String title,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
    String? suffix,
  }) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFF1E3A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Color(0xFF1E3A8A), size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                hintText: hint,
                suffixText: suffix,
                suffixStyle: TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              keyboardType: keyboardType,
              onSaved: onSaved,
              validator: validator,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Calculadora de Interés',
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header
                  Container(
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
                        Icon(Icons.calculate, size: 48, color: Colors.white),
                        SizedBox(height: 12),
                        Text(
                          'Calculadora de Interés Compuesto',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Calcula el crecimiento de tu inversión',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Inputs
                  _buildInputCard(
                    title: 'Capital Inicial',
                    hint: 'Ingresa el monto inicial',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    onSaved: (value) => _capital = double.parse(value!),
                    validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                    suffix: 'USD',
                  ),
                  SizedBox(height: 16),

                  _buildInputCard(
                    title: 'Tasa de Interés',
                    hint: 'Porcentaje por vuelta',
                    icon: Icons.percent,
                    keyboardType: TextInputType.number,
                    onSaved: (value) => _rate = double.parse(value!),
                    validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                    suffix: '%',
                  ),
                  SizedBox(height: 16),

                  _buildInputCard(
                    title: 'Número de Vueltas',
                    hint: 'Cantidad de períodos',
                    icon: Icons.repeat,
                    keyboardType: TextInputType.number,
                    onSaved: (value) => _rounds = int.parse(value!),
                    validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                  ),
                  SizedBox(height: 32),

                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _calculate,
                            icon: Icon(Icons.calculate, color: Colors.white),
                            label: Text(
                              'Calcular',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF1E3A8A),
                              elevation: 8,
                              shadowColor: Color(0xFF1E3A8A).withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Container(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _reset,
                          icon: Icon(Icons.refresh, color: Color(0xFF1E3A8A)),
                          label: Text(
                            'Limpiar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Color(0xFF1E3A8A), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32),

                  // Resultado
                  if (_showResult)
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[400]!, Colors.green[600]!],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.trending_up, size: 48, color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Resultado Final',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              formatter.format(_result),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Ganancia: ${formatter.format(_result - _capital)}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

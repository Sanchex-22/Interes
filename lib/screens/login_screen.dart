import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Firestore
import 'package:interest_compound_game/models/app_models.dart'; // Importa tus modelos de datos
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _isLoading = false;
  bool _isLogin = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Eliminada la instancia de GoogleSignIn

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  // Crea o actualiza las colecciones de usuario en Firestore
  Future<void> _createOrUpdateUserCollections(User user) async {
    final firestore = FirebaseFirestore.instance;
    final userDocRef = firestore.collection('users').doc(user.uid);
    final rankingDocRef = firestore.collection('rankings').doc(user.uid);

    try {
      // 1. Crear/Actualizar el documento del usuario (users collection)
      final userDocSnapshot = await userDocRef.get();
      if (!userDocSnapshot.exists) {
        print('Firestore: Perfil de usuario no encontrado para ${user.uid}. Creando uno básico.');
        final newUserModel = UserModel(
          uid: user.uid,
          email: user.email!,
          displayName: user.displayName,
          registrationDate: DateTime.now(),
          lastLoginDate: DateTime.now(),
          role: 'user',
          totalCalculations: 0,
          totalScore: 0.0,
          currentStreak: 0,
          lastActivityDate: null,
        );
        await userDocRef.set(newUserModel.toFirestore());
        print('Firestore: Perfil de usuario creado exitosamente.');
      } else {
        print('Firestore: Perfil de usuario existente para ${user.uid}. Actualizando lastLoginDate.');
        await userDocRef.update({
          'lastLoginDate': Timestamp.fromDate(DateTime.now()),
        });
      }

      // 2. Crear una entrada inicial en la colección 'rankings' si no existe
      final rankingDocSnapshot = await rankingDocRef.get();
      if (!rankingDocSnapshot.exists) {
        print('Firestore: Entrada de ranking no encontrada para ${user.uid}. Creando una inicial.');
        final newRankingModel = RankingModel(
          userId: user.uid,
          userName: user.displayName ?? user.email!,
          bestScore: 0.0,
          lastUpdated: DateTime.now(),
          averageScore: 0.0,
          totalCalculations: 0,
        );
        await rankingDocRef.set(newRankingModel.toFirestore());
        print('Firestore: Entrada de ranking inicial creada exitosamente.');
      } else {
        print('Firestore: Entrada de ranking ya existe para ${user.uid}.');
      }

    } on FirebaseException catch (e) {
      print('Firestore Error (createOrUpdateUserCollections): Código: ${e.code}, Mensaje: ${e.message}');
      _showSnackBar('Error al configurar el perfil de usuario en la base de datos: ${e.message}', backgroundColor: Colors.red);
    } catch (e) {
      print('Error desconocido al configurar el perfil de usuario en la base de datos: $e');
      _showSnackBar('Error desconocido al configurar el perfil de usuario.', backgroundColor: Colors.red);
    }
  }

  // Función para manejar la lógica después de cualquier autenticación exitosa
  Future<void> _handlePostAuthLogic(User user) async {
    // Primero, asegura que las colecciones de Firestore estén configuradas
    await _createOrUpdateUserCollections(user);
    // Luego, intenta migrar cualquier dato de invitado
    await _migrateGuestData(user);
    // Finalmente, navega al Dashboard
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  // Función para migrar datos de un usuario invitado a su cuenta de Firebase
  Future<void> _migrateGuestData(User authenticatedUser) async {
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool('isGuest') ?? false;

    if (isGuest) {
      print('Migrando datos de invitado para ${authenticatedUser.uid}...');
      final firestore = FirebaseFirestore.instance;
      final userDocRef = firestore.collection('users').doc(authenticatedUser.uid);
      final rankingDocRef = firestore.collection('rankings').doc(authenticatedUser.uid);

      try {
        // Leer datos de invitado
        final guestTotalCalculations = prefs.getInt('guest_totalCalculations') ?? 0;
        final guestTotalScore = prefs.getDouble('guest_totalScore') ?? 0.0;
        final guestCurrentStreak = prefs.getInt('guest_currentStreak') ?? 0;
        // Para dailyGoals, necesitarías una lógica de serialización/deserialización más compleja
        // Por ejemplo: List<String> dailyGoalsJson = prefs.getStringList('guest_dailyGoals') ?? [];
        // Y luego convertir cada string JSON de vuelta a DailyGoalEntry

        // Obtener el perfil de usuario existente en Firestore
        final userDocSnapshot = await userDocRef.get();
        UserModel currentUserProfile;
        if (userDocSnapshot.exists) {
          currentUserProfile = UserModel.fromFirestore(userDocSnapshot);
        } else {
          // Esto no debería ocurrir si _createOrUpdateUserCollections se llamó primero
          currentUserProfile = UserModel(
            uid: authenticatedUser.uid,
            email: authenticatedUser.email!,
            displayName: authenticatedUser.displayName,
            registrationDate: DateTime.now(),
            lastLoginDate: DateTime.now(),
          );
        }

        // Combinar datos: tomar el máximo entre los datos existentes y los de invitado
        final updatedTotalCalculations = (currentUserProfile.totalCalculations ?? 0) + guestTotalCalculations;
        final updatedTotalScore = (currentUserProfile.totalScore ?? 0.0) + guestTotalScore;
        final updatedCurrentStreak = (currentUserProfile.currentStreak ?? 0) > guestCurrentStreak
            ? (currentUserProfile.currentStreak ?? 0)
            : guestCurrentStreak; // Mantener la racha más alta

        // Actualizar el documento de usuario en Firestore
        await userDocRef.update({
          'totalCalculations': updatedTotalCalculations,
          'totalScore': updatedTotalScore,
          'currentStreak': updatedCurrentStreak,
          'lastActivityDate': Timestamp.fromDate(DateTime.now()), // Actualizar la última actividad
        });

        // Actualizar el documento de ranking en Firestore
        await rankingDocRef.set({
          'userName': authenticatedUser.displayName ?? authenticatedUser.email!,
          'bestScore': updatedTotalScore,
          'currentStreak': updatedCurrentStreak,
          'lastUpdated': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true)); // Usar merge para no sobrescribir todo

        print('Datos de invitado migrados exitosamente a Firestore.');
        _showSnackBar('¡Progreso de invitado guardado en tu cuenta!', backgroundColor: Colors.blue);

        // Limpiar datos de invitado de SharedPreferences
        await prefs.remove('isGuest');
        await prefs.remove('guest_totalCalculations');
        await prefs.remove('guest_totalScore');
        await prefs.remove('guest_currentStreak');
        // await prefs.remove('guest_dailyGoals'); // Si se implementa dailyGoals
        print('Datos de invitado limpiados de SharedPreferences.');

      } on FirebaseException catch (e) {
        print('Firestore Error (migrateGuestData): Código: ${e.code}, Mensaje: ${e.message}');
        _showSnackBar('Error al migrar datos de invitado: ${e.message}', backgroundColor: Colors.red);
      } catch (e) {
        print('Error desconocido al migrar datos de invitado: $e');
        _showSnackBar('Error desconocido al migrar datos de invitado.', backgroundColor: Colors.red);
      }
    }
  }

  // Función para iniciar sesión anónimamente
  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoading = true;
    });
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      print('Inicio de sesión anónimo exitoso: ${userCredential.user!.uid}');

      // Marcar esta sesión como de invitado en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGuest', true);

      // Inicializar progreso de invitado en SharedPreferences si no existe
      if (!prefs.containsKey('guest_totalCalculations')) {
        await prefs.setInt('guest_totalCalculations', 0);
        await prefs.setDouble('guest_totalScore', 0.0);
        await prefs.setInt('guest_currentStreak', 0);
      }

      Navigator.pushReplacementNamed(context, '/dashboard');
    } on FirebaseAuthException catch (e) {
      String message = 'Error al iniciar sesión como invitado: ${e.message}';
      _showSnackBar(message, backgroundColor: Colors.red);
      print('Error en inicio de sesión anónimo: ${e.code} - ${e.message}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        // --- VERIFICACIÓN DE CORREO ---
        if (userCredential.user != null && !userCredential.user!.emailVerified) {
          _showSnackBar(
            'Por favor, verifica tu correo electrónico antes de iniciar sesión. Revisa tu bandeja de entrada.',
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 6),
          );
          await _auth.signOut(); // Cierra la sesión si no está verificado
          return; // Detiene el proceso de login
        }
        // --- FIN VERIFICACIÓN DE CORREO ---

        print('Inicio de sesión exitoso: ${userCredential.user!.email}');
        
        if (userCredential.user != null) {
          await _handlePostAuthLogic(userCredential.user!);
        }
      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'user-not-found') {
          message = 'No se encontró ningún usuario con ese correo electrónico.';
        } else if (e.code == 'wrong-password') {
          message = 'Contraseña incorrecta para ese correo electrónico.';
        } else if (e.code == 'invalid-email') {
          message = 'El formato del correo electrónico es inválido.';
        } else if (e.code == 'user-disabled') {
          message = 'Este usuario ha sido deshabilitado.';
        }
        else {
          message = 'Error de inicio de sesión: ${e.message}';
        }
        _showSnackBar(message, backgroundColor: Colors.red);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        print('Registro exitoso: ${userCredential.user!.email}');
        
        // --- ENVÍO DE VERIFICACIÓN DE CORREO ---
        if (userCredential.user != null) {
          await userCredential.user!.sendEmailVerification();
          _showSnackBar(
            '¡Registro exitoso! Se ha enviado un correo de verificación a tu email. Por favor, verifica tu cuenta antes de iniciar sesión.',
            backgroundColor: Colors.green,
            duration: Duration(seconds: 8),
          );
        }
        // --- FIN ENVÍO DE VERIFICACIÓN DE CORREO ---

        // Después del registro, si el usuario era invitado, migrar datos
        if (userCredential.user != null) {
          await _handlePostAuthLogic(userCredential.user!);
        } else {
          // Si por alguna razón userCredential.user es nulo, simplemente vuelve al login
          setState(() {
            _isLogin = true; // Vuelve a la pantalla de login después del registro
          });
        }
      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'weak-password') {
          message = 'La contraseña es demasiado débil.';
        } else if (e.code == 'email-already-in-use') {
          message = 'El correo electrónico ya está en uso por otra cuenta.';
        } else {
          message = 'Error de registro: ${e.message}';
        }
        _showSnackBar(message, backgroundColor: Colors.red);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF3B82F6),
              Color(0xFF60A5FA),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Card(
                    elevation: 20,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo/Icon
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.trending_up,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              _isLogin ? 'Bienvenido' : 'Crear Cuenta',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Interés Compuesto Game',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 32),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Correo Electrónico',
                                prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF1E3A8A)),
                                labelStyle: TextStyle(color: Colors.grey[700]),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              onSaved: (value) => _email = value!.trim(),
                              validator: (value) => value!.isEmpty 
                                  ? 'Campo requerido' 
                                  : (value.contains('@') ? null : 'Correo electrónico inválido'),
                            ),
                            SizedBox(height: 20),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF1E3A8A)),
                                labelStyle: TextStyle(color: Colors.grey[700]),
                              ),
                              obscureText: true,
                              onSaved: (value) => _password = value!,
                              validator: (value) => value!.isEmpty 
                                  ? 'Campo requerido' 
                                  : (value.length < 6 ? 'La contraseña debe tener al menos 6 caracteres' : null),
                            ),
                            SizedBox(height: 32),
                            _isLoading
                                ? Container(
                                    width: 50,
                                    height: 50,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Column(
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        height: 56,
                                        child: ElevatedButton(
                                          onPressed: _isLogin ? _login : _register,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF1E3A8A),
                                            foregroundColor: Colors.white,
                                            elevation: 8,
                                            shadowColor: Color(0xFF1E3A8A).withOpacity(0.4),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: Text(
                                            _isLogin ? 'Iniciar Sesión' : 'Registrarse',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      // Botón de Google Sign-In ELIMINADO
                                      // Container(
                                      //   width: double.infinity,
                                      //   height: 56,
                                      //   child: OutlinedButton.icon(
                                      //     onPressed: _signInWithGoogle,
                                      //     style: OutlinedButton.styleFrom(
                                      //       side: BorderSide(color: Colors.grey[300]!, width: 1),
                                      //       backgroundColor: Colors.white,
                                      //       shape: RoundedRectangleBorder(
                                      //         borderRadius: BorderRadius.circular(16),
                                      //       ),
                                      //       elevation: 4,
                                      //       shadowColor: Colors.black12,
                                      //     ),
                                      //     icon: Image.network(
                                      //       'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/2048px-Google_%22G%22_logo.svg.png',
                                      //       height: 24,
                                      //       width: 24,
                                      //       errorBuilder: (context, error, stackTrace) => Icon(Icons.g_mobiledata, size: 24), // Fallback icon
                                      //     ),
                                      //     label: Text(
                                      //       'Continuar con Google',
                                      //       style: TextStyle(
                                      //         fontSize: 18,
                                      //         fontWeight: FontWeight.w600,
                                      //         color: Colors.grey[700],
                                      //       ),
                                      //     ),
                                      //   ),
                                      // ),
                                      SizedBox(height: 16),
                                      // NUEVO: Botón para continuar como invitado
                                      Container(
                                        width: double.infinity,
                                        height: 56,
                                        child: OutlinedButton.icon(
                                          onPressed: _signInAnonymously,
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: Color(0xFF3B82F6).withOpacity(0.5), width: 1),
                                            backgroundColor: Color(0xFFE0F2F7), // Un color más suave para el invitado
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            elevation: 4,
                                            shadowColor: Colors.blue.shade100,
                                          ),
                                          icon: Icon(Icons.person_outline, color: Color(0xFF1E3A8A)),
                                          label: Text(
                                            'Continuar como Invitado',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E3A8A),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _isLogin = !_isLogin;
                                          });
                                        },
                                        child: RichText(
                                          text: TextSpan(
                                            style: TextStyle(color: Colors.grey[600]),
                                            children: [
                                              TextSpan(
                                                text: _isLogin 
                                                    ? '¿No tienes cuenta? ' 
                                                    : '¿Ya tienes cuenta? ',
                                              ),
                                              TextSpan(
                                                text: _isLogin ? 'Regístrate' : 'Inicia sesión',
                                                style: TextStyle(
                                                  color: Color(0xFF1E3A8A),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

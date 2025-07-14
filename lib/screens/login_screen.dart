import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Firestore
import 'package:interest_compound_game/models/app_models.dart'; // Importa tus modelos de datos

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

  // NUEVA FUNCIÓN: Crea o actualiza las colecciones de usuario en Firestore
  Future<void> _createOrUpdateUserCollections(User user) async {
    final firestore = FirebaseFirestore.instance;
    final userDocRef = firestore.collection('users').doc(user.uid);
    final rankingDocRef = firestore.collection('rankings').doc(user.uid);

    try {
      // 1. Crear/Actualizar el documento del usuario (users collection)
      final userDocSnapshot = await userDocRef.get();
      if (!userDocSnapshot.exists) {
        // Si el perfil de usuario NO existe, lo creamos con valores por defecto
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
        // Si el perfil de usuario YA existe, solo actualizamos la fecha de último login
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

      // La colección 'calculations' se creará de forma natural cuando el usuario realice su primer cálculo.
      // No es necesario crear un documento vacío inicial aquí.

    } on FirebaseException catch (e) {
      print('Firestore Error (createOrUpdateUserCollections): Código: ${e.code}, Mensaje: ${e.message}');
      _showErrorSnackBar('Error al configurar el perfil de usuario en la base de datos: ${e.message}');
    } catch (e) {
      print('Error desconocido al configurar el perfil de usuario en la base de datos: $e');
      _showErrorSnackBar('Error desconocido al configurar el perfil de usuario.');
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
        print('Inicio de sesión exitoso: ${userCredential.user!.email}');
        
        // LLAMADA CLAVE: Crear/actualizar colecciones después del login exitoso
        if (userCredential.user != null) {
          await _createOrUpdateUserCollections(userCredential.user!);
        }

        Navigator.pushReplacementNamed(context, '/dashboard');
      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'user-not-found') {
          message = 'No se encontró ningún usuario con ese correo electrónico.';
        } else if (e.code == 'wrong-password') {
          message = 'Contraseña incorrecta para ese correo electrónico.';
        } else if (e.code == 'invalid-email') {
          message = 'El formato del correo electrónico es inválido.';
        } else {
          message = 'Error de inicio de sesión: ${e.message}';
        }
        _showErrorSnackBar(message);
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
        
        // LLAMADA CLAVE: Crear colecciones después del registro exitoso
        if (userCredential.user != null) {
          await _createOrUpdateUserCollections(userCredential.user!);
        }

        _showSuccessSnackBar('Usuario registrado exitosamente. Ahora puedes iniciar sesión.');
        setState(() {
          _isLogin = true; // Vuelve a la pantalla de login después del registro
        });
      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'weak-password') {
          message = 'La contraseña es demasiado débil.';
        } else if (e.code == 'email-already-in-use') {
          message = 'El correo electrónico ya está en uso por otra cuenta.';
        } else {
          message = 'Error de registro: ${e.message}';
        }
        _showErrorSnackBar(message);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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

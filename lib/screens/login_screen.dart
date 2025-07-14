import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa firebase_auth

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = ''; // Cambiamos a email
  String _password = '';
  bool _isLoading = false; // Para manejar el estado de carga

  final FirebaseAuth _auth = FirebaseAuth.instance; // Instancia de FirebaseAuth

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true; // Inicia el estado de carga
      });

      try {
        // Intenta iniciar sesión con correo y contraseña
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        // Si el inicio de sesión es exitoso, navega al dashboard
        print('Inicio de sesión exitoso: ${userCredential.user!.email}');
        Navigator.pushReplacementNamed(context, '/dashboard');
      } on FirebaseAuthException catch (e) {
        // Manejo de errores de Firebase
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } finally {
        setState(() {
          _isLoading = false; // Finaliza el estado de carga
        });
      }
    }
  }

  // Opcional: Función para registrar un nuevo usuario si no existe
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario registrado exitosamente. Ahora puedes iniciar sesión.')),
        );
      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'weak-password') {
          message = 'La contraseña es demasiado débil.';
        } else if (e.code == 'email-already-in-use') {
          message = 'El correo electrónico ya está en uso por otra cuenta.';
        } else {
          message = 'Error de registro: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Iniciar Sesión', style: TextStyle(fontSize: 24)),
                SizedBox(height: 20),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico', // Cambiado a correo electrónico
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onSaved: (value) => _email = value!.trim(), // Usamos trim() para limpiar espacios
                  validator: (value) => value!.isEmpty ? 'Campo requerido' : (value.contains('@') ? null : 'Correo electrónico inválido'),
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onSaved: (value) => _password = value!,
                  validator: (value) => value!.isEmpty ? 'Campo requerido' : (value.length < 6 ? 'La contraseña debe tener al menos 6 caracteres' : null),
                ),
                SizedBox(height: 20),
                _isLoading
                    ? CircularProgressIndicator() // Muestra un indicador de carga
                    : Column(
                        children: [
                          ElevatedButton(
                            onPressed: _login,
                            child: Text('Entrar'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50), // Botón más ancho
                            ),
                          ),
                          SizedBox(height: 10),
                          TextButton(
                            onPressed: _register, // Botón para registrar
                            child: Text('¿No tienes cuenta? Regístrate aquí'),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Cloud Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Importa Firebase Auth (si lo necesitas para filtrar)
import 'package:interest_compound_game/models/app_models.dart'; // Importa tus modelos de datos

// La clase RankEntry ya no es estrictamente necesaria si usamos directamente RankingModel
// Pero la mantendremos si quieres una capa de abstracción o datos específicos para el UI.
// Sin embargo, para simplificar, usaremos RankingModel directamente en la lista.

class RankingScreen extends StatefulWidget {
  @override
  _RankingScreenState createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  // Instancias de Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Se mantiene por si se necesita el UID del usuario actual

  // Datos del ranking (ahora de tipo RankingModel)
  List<RankingModel> _rankingData = [];
  bool _isLoading = true; // Para mostrar un indicador de carga
  String? _errorMessage; // Para mostrar mensajes de error

  @override
  void initState() {
    super.initState();
    _loadRankingData(); // Llama a la función para cargar los datos
  }

  // Función para cargar los datos del ranking desde Firestore
  Future<void> _loadRankingData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Limpia cualquier error anterior
      _rankingData = []; // Limpia los datos anteriores
    });

    try {
      // Consulta la colección 'rankings'
      // Ordena por 'bestScore' de forma descendente (puntuación más alta primero)
      // Limita a, por ejemplo, los top 20 para no cargar demasiados datos
      final QuerySnapshot snapshot = await _firestore.collection('rankings')
          .orderBy('bestScore', descending: true)
          .limit(20) // Puedes ajustar este límite
          .get();

      // Convierte los documentos de Firestore a objetos RankingModel
      final List<RankingModel> fetchedRankings = snapshot.docs.map((doc) {
        return RankingModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      }).toList();

      setState(() {
        _rankingData = fetchedRankings;
      });

    } on FirebaseException catch (e) {
      // Captura errores específicos de Firebase
      setState(() {
        _errorMessage = 'Error de Firestore al cargar el ranking: ${e.code} - ${e.message}';
      });
      print('Firestore Error (RankingScreen): ${e.code} - ${e.message}');
    } catch (e) {
      // Captura cualquier otro tipo de error
      setState(() {
        _errorMessage = 'Error desconocido al cargar el ranking: ${e.toString()}';
      });
      print('Error loading ranking: $e');
    } finally {
      setState(() {
        _isLoading = false; // Finaliza el estado de carga
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Fondo consistente
      appBar: AppBar(
        title: const Text(
          'Ranking de Puntuaciones',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Color(0xFF1E3A8A), // Color consistente
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
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRankingData, // Botón para recargar el ranking
            tooltip: 'Recargar Ranking',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))) // Muestra un spinner mientras carga
          : _errorMessage != null
              ? Center(
                  // Muestra un mensaje de error si algo salió mal
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 40),
                        SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadRankingData, // Botón para reintentar
                          child: Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _rankingData.isEmpty // Verifica si la lista de datos está vacía
                  ? Center(
                      // Si la lista está vacía, muestra un mensaje amigable
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.leaderboard_outlined, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 20),
                          const Text(
                            '¡Aún no hay puntuaciones en el ranking!',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Realiza algunos cálculos para aparecer aquí.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // Cierra la pantalla de ranking
                              // Opcional: Navigator.pushReplacementNamed(context, '/calculator');
                            },
                            icon: Icon(Icons.calculate, color: Colors.white),
                            label: Text(
                              'Ir a Calcular',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF1E3A8A),
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      // Si hay datos, construye la lista
                      itemCount: _rankingData.length,
                      itemBuilder: (context, index) {
                        final entry = _rankingData[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Color(0xFF1E3A8A), // Color consistente
                              child: Text(
                                '${index + 1}', // Posición en el ranking
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              entry.userName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              'Puntuación: ${entry.bestScore.toStringAsFixed(2)}', // Usa bestScore
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            trailing: Text(
                              // Formato de fecha completo (día/mes/año)
                              '${entry.lastUpdated.day}/${entry.lastUpdated.month}/${entry.lastUpdated.year}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Detalles de ${entry.userName} (ID: ${entry.userId})')),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}

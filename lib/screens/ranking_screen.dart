import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Cloud Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Importa Firebase Auth (si lo necesitas para filtrar)
import 'package:interest_compound_game/models/app_models.dart'; // Importa tus modelos de datos

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
  String? _currentUserId; // Para almacenar el UID del usuario actual

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid; // Obtener el UID del usuario actual
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
      // Ordena por 'currentStreak' de forma descendente (racha más alta primero)
      // También puedes añadir un segundo criterio de ordenación si las rachas son iguales, por ejemplo, por bestScore
      final QuerySnapshot snapshot = await _firestore.collection('rankings')
          .orderBy('currentStreak', descending: true) // Ordena por racha
          .orderBy('bestScore', descending: true) // Segundo criterio: por puntuación si las rachas son iguales
          .limit(50) // Aumenta el límite para obtener más datos y luego deduplicar
          .get();

      // Convierte los documentos de Firestore a objetos RankingModel
      final List<RankingModel> fetchedRankings = snapshot.docs.map((doc) {
        return RankingModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      }).toList();

      // Deduplicar la lista de rankings por userId
      // Usamos un mapa para almacenar una única entrada por userId.
      // Si hay duplicados en Firestore, esta lógica conservará la primera que encuentre
      // (que debido a la ordenación, debería ser la más relevante si las rachas son iguales).
      final Map<String, RankingModel> uniqueRankingsMap = {};
      for (var entry in fetchedRankings) {
        if (!uniqueRankingsMap.containsKey(entry.userId)) {
          uniqueRankingsMap[entry.userId] = entry;
        }
      }

      // Convierte el mapa de vuelta a una lista
      final List<RankingModel> deduplicatedRankings = uniqueRankingsMap.values.toList();

      setState(() {
        _rankingData = deduplicatedRankings;
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

  // Función auxiliar para limpiar el nombre de usuario
  String _cleanUserName(String userName) {
    if (userName.contains('@')) {
      return userName.substring(0, userName.indexOf('@'));
    }
    return userName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Fondo consistente
      appBar: AppBar(
        title: const Text(
          'Ranking de Rachas', // Título actualizado
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
                            '¡Aún no hay rachas en el ranking!', // Mensaje actualizado
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Juega y mantén tu racha para aparecer aquí.', // Mensaje actualizado
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
                              'Ir a Jugar', // Texto actualizado
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
                        // Determina si esta entrada es del usuario actual
                        final isCurrentUser = entry.userId == _currentUserId;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          // Aplica un color de fondo diferente si es el usuario actual
                          color: isCurrentUser ? Colors.blue.shade50 : Colors.white, // Color de resaltado
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isCurrentUser ? Color(0xFF3B82F6) : Color(0xFF1E3A8A), // Color consistente, resaltado para el usuario actual
                              child: Text(
                                '${index + 1}', // Posición en el ranking
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Row( // Usamos un Row para el nombre y la racha
                              mainAxisSize: MainAxisSize.min, // Ajusta el tamaño del Row a su contenido
                              children: [
                                Flexible( // Permite que el nombre se ajuste si es largo
                                  child: Text(
                                    _cleanUserName(entry.userName),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isCurrentUser ? Color(0xFF1E3A8A) : Colors.black87, // Color de texto para el nombre
                                    ),
                                    overflow: TextOverflow.ellipsis, // Recorta el texto si es demasiado largo
                                  ),
                                ),
                                const SizedBox(width: 8), // Espacio entre el nombre y el icono
                                Icon(Icons.local_fire_department, color: Colors.orange, size: 18), // Icono de fuego
                                const SizedBox(width: 4), // Espacio entre el icono y la racha
                                Text(
                                  '${entry.currentStreak} días', // Muestra la racha
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange[700]),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Última act.: ${entry.lastUpdated.day}/${entry.lastUpdated.month}/${entry.lastUpdated.year}', // Muestra la fecha de última actualización
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                            // Se eliminó el trailing IconButton
                          ),
                        );
                      },
                    ),
    );
  }
}

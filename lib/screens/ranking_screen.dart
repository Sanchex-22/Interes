import 'package:flutter/material.dart';
// Puedes añadir importaciones de Firebase si el ranking se carga de Firestore
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// Clase de ejemplo para un elemento del ranking.
// Adapta esto a la estructura real de tus datos de ranking.
class RankEntry {
  final String userName;
  final double score;
  final DateTime date;

  RankEntry({required this.userName, required this.score, required this.date});

  // Método para crear una entrada desde un mapa (útil para Firestore)
  factory RankEntry.fromMap(Map<String, dynamic> data) {
    return RankEntry(
      userName: data['userName'] ?? 'Desconocido',
      score: (data['score'] as num?)?.toDouble() ?? 0.0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class Timestamp extends Object {
  final int seconds;
  final int nanoseconds;

  Timestamp({required this.seconds, required this.nanoseconds});

  factory Timestamp.fromDate(DateTime date) {
    final int milliseconds = date.millisecondsSinceEpoch;
    return Timestamp(
      seconds: milliseconds ~/ 1000,
      nanoseconds: (milliseconds % 1000) * 1000000,
    );
  }

  DateTime toDate() {
    return DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000 + nanoseconds ~/ 1000000,
    );
  }
}

class RankingScreen extends StatefulWidget {
  @override
  _RankingScreenState createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  // Aquí almacenarías tus datos de ranking.
  // Por ahora, es una lista vacía que simula "no hay cálculos".
  List<RankEntry> _rankingData = [];
  bool _isLoading = true; // Para mostrar un indicador de carga
  String? _errorMessage; // Para mostrar mensajes de error

  @override
  void initState() {
    super.initState();
    _loadRankingData(); // Llama a la función para cargar los datos
  }

  // Función para cargar los datos del ranking.
  // Aquí es donde integrarías la lógica para obtener los datos.
  Future<void> _loadRankingData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Limpia cualquier error anterior
    });

    try {
      // Simulación de una carga de datos asíncrona
      await Future.delayed(const Duration(seconds: 1)); // Simula un retraso de red

      // --- Lógica para cargar datos reales ---
      // Si usas Firestore, sería algo como esto:
      // final FirebaseFirestore firestore = FirebaseFirestore.instance;
      // final QuerySnapshot snapshot = await firestore.collection('rankings')
      //     .orderBy('score', descending: true) // Ordena por puntuación
      //     .limit(10) // Limita a los top 10
      //     .get();
      //
      // setState(() {
      //   _rankingData = snapshot.docs.map((doc) => RankEntry.fromMap(doc.data() as Map<String, dynamic>)).toList();
      // });

      // *** SIMULACIÓN DE DATOS ***
      // Para probar el caso de "no hay datos", manten _rankingData como una lista vacía.
      // Para probar con datos, descomenta la siguiente línea:
      // _rankingData = [
      //   RankEntry(userName: 'JugadorA', score: 1250.0, date: DateTime.now().subtract(Duration(days: 1))),
      //   RankEntry(userName: 'JugadorB', score: 1100.0, date: DateTime.now().subtract(Duration(hours: 5))),
      //   RankEntry(userName: 'JugadorC', score: 980.0, date: DateTime.now()),
      // ];
      // *** FIN SIMULACIÓN ***

    } catch (e) {
      // Captura cualquier error durante la carga de datos
      setState(() {
        _errorMessage = 'Error al cargar el ranking: ${e.toString()}';
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
      appBar: AppBar(
        title: const Text('Ranking de Puntuaciones'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Muestra un spinner mientras carga
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
                              // Esto asume que tienes una ruta para la calculadora o la pantalla principal
                              Navigator.pop(context); // Cierra la pantalla de ranking
                              // Opcional: Navigator.pushReplacementNamed(context, '/calculator');
                            },
                            icon: Icon(Icons.calculate),
                            label: Text('Ir a Calcular'),
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
                              backgroundColor: Colors.indigoAccent,
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
                              'Puntuación: ${entry.score.toStringAsFixed(2)}', // Formatea la puntuación
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            trailing: Text(
                              '${entry.date.day}/${entry.date.month}', // Muestra solo día/mes
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                            // Puedes añadir un onTap para ver detalles de la entrada
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Detalles de ${entry.userName}')),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo para la colección 'users'
class UserModel {
  final String uid;
  final String email;
  final String? displayName; // Puede ser nulo
  final int totalCalculations;
  final double totalScore;
  final int currentStreak;
  final DateTime? lastActivityDate; // Puede ser nulo si no ha habido actividad
  final DateTime registrationDate;
  final DateTime? lastLoginDate; // Puede ser nulo
  final String role; // Nuevo campo para el rol del usuario

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.totalCalculations = 0,
    this.totalScore = 0.0,
    this.currentStreak = 0,
    this.lastActivityDate,
    required this.registrationDate,
    this.lastLoginDate,
    this.role = 'user', // Rol por defecto
  });

  // Constructor para crear un UserModel desde un documento de Firestore
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) {
    final data = snapshot.data();
    return UserModel(
      uid: snapshot.id, // El ID del documento es el UID del usuario
      email: data?['email'] as String? ?? '',
      displayName: data?['displayName'] as String?,
      totalCalculations: (data?['totalCalculations'] as num?)?.toInt() ?? 0,
      totalScore: (data?['totalScore'] as num?)?.toDouble() ?? 0.0,
      currentStreak: (data?['currentStreak'] as num?)?.toInt() ?? 0,
      lastActivityDate: (data?['lastActivityDate'] as Timestamp?)?.toDate(),
      registrationDate: (data?['registrationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginDate: (data?['lastLoginDate'] as Timestamp?)?.toDate(),
      role: data?['role'] as String? ?? 'user',
    );
  }

  // Método para convertir un UserModel a un mapa para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      "email": email,
      "displayName": displayName,
      "totalCalculations": totalCalculations,
      "totalScore": totalScore,
      "currentStreak": currentStreak,
      "lastActivityDate": lastActivityDate != null ? Timestamp.fromDate(lastActivityDate!) : null,
      "registrationDate": Timestamp.fromDate(registrationDate),
      "lastLoginDate": lastLoginDate != null ? Timestamp.fromDate(lastLoginDate!) : null,
      "role": role,
    };
  }

  // Método para actualizar campos específicos (útil para `update` en Firestore)
  Map<String, dynamic> toUpdateMap() {
    final Map<String, dynamic> map = {};
    if (displayName != null) map['displayName'] = displayName;
    map['totalCalculations'] = totalCalculations;
    map['totalScore'] = totalScore;
    map['currentStreak'] = currentStreak;
    if (lastActivityDate != null) map['lastActivityDate'] = Timestamp.fromDate(lastActivityDate!);
    if (lastLoginDate != null) map['lastLoginDate'] = Timestamp.fromDate(lastLoginDate!);
    if (role != 'user') map['role'] = role; // Solo actualiza si no es el rol por defecto
    return map;
  }
}

// Modelo para la colección 'calculations'
class CalculationModel {
  final String id; // ID del documento de cálculo
  final String userId;
  final String calculationType;
  final double initialAmount;
  final double interestRate;
  final double timePeriod;
  final double finalResult;
  final double scoreAchieved;
  final DateTime timestamp;

  CalculationModel({
    required this.id,
    required this.userId,
    required this.calculationType,
    required this.initialAmount,
    required this.interestRate,
    required this.timePeriod,
    required this.finalResult,
    required this.scoreAchieved,
    required this.timestamp,
  });

  // Constructor para crear un CalculationModel desde un documento de Firestore
  factory CalculationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) {
    final data = snapshot.data();
    return CalculationModel(
      id: snapshot.id,
      userId: data?['userId'] as String? ?? '',
      calculationType: data?['calculationType'] as String? ?? '',
      initialAmount: (data?['initialAmount'] as num?)?.toDouble() ?? 0.0,
      interestRate: (data?['interestRate'] as num?)?.toDouble() ?? 0.0,
      timePeriod: (data?['timePeriod'] as num?)?.toDouble() ?? 0.0,
      finalResult: (data?['finalResult'] as num?)?.toDouble() ?? 0.0,
      scoreAchieved: (data?['scoreAchieved'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data?['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Método para convertir un CalculationModel a un mapa para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      "userId": userId,
      "calculationType": calculationType,
      "initialAmount": initialAmount,
      "interestRate": interestRate,
      "timePeriod": timePeriod,
      "finalResult": finalResult,
      "scoreAchieved": scoreAchieved,
      "timestamp": Timestamp.fromDate(timestamp),
    };
  }
}

// Modelo para la colección 'rankings'
class RankingModel {
  final String userId; // El ID del documento es el UID del usuario
  final String userName;
  final double bestScore;
  final DateTime lastUpdated;
  final double averageScore; // Puede ser nulo o no usado si no es relevante
  final int totalCalculations;

  RankingModel({
    required this.userId,
    required this.userName,
    required this.bestScore,
    required this.lastUpdated,
    this.averageScore = 0.0,
    this.totalCalculations = 0,
  });

  // Constructor para crear un RankingModel desde un documento de Firestore
  factory RankingModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) {
    final data = snapshot.data();
    return RankingModel(
      userId: snapshot.id, // El ID del documento es el UID del usuario
      userName: data?['userName'] as String? ?? '',
      bestScore: (data?['bestScore'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: (data?['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      averageScore: (data?['averageScore'] as num?)?.toDouble() ?? 0.0,
      totalCalculations: (data?['totalCalculations'] as num?)?.toInt() ?? 0,
    );
  }

  // Método para convertir un RankingModel a un mapa para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      "userName": userName,
      "bestScore": bestScore,
      "lastUpdated": Timestamp.fromDate(lastUpdated),
      "averageScore": averageScore,
      "totalCalculations": totalCalculations,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallengeType {
  totalWorkouts,
  totalExercises,
  totalMinutes,
  consecutiveDays,
}

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final int targetValue;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> participants;
  final Map<String, int> leaderboard;

  ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.startDate,
    required this.endDate,
    required this.participants,
    required this.leaderboard,
  });

  bool isActive() {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  String get typeString {
    switch (type) {
      case ChallengeType.totalWorkouts:
        return 'workouts';
      case ChallengeType.totalExercises:
        return 'exercises';
      case ChallengeType.totalMinutes:
        return 'minutes';
      case ChallengeType.consecutiveDays:
        return 'days';
    }
  }

  static ChallengeType typeFromString(String str) {
    switch (str) {
      case 'exercises':
        return ChallengeType.totalExercises;
      case 'minutes':
        return ChallengeType.totalMinutes;
      case 'days':
        return ChallengeType.consecutiveDays;
      default:
        return ChallengeType.totalWorkouts;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': typeString,
      'targetValue': targetValue,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'participants': participants,
      'leaderboard': leaderboard,
    };
  }

  factory ChallengeModel.fromMap(Map<String, dynamic> map, String docId) {
    return ChallengeModel(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: typeFromString(map['type'] ?? 'workouts'),
      targetValue: map['targetValue'] ?? 0,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      participants: List<String>.from(map['participants'] ?? []),
      leaderboard: Map<String, int>.from(map['leaderboard'] ?? {}),
    );
  }
}
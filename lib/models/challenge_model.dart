import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final String type; // 'workouts', 'exercises', 'duration'
  final int targetValue;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> participants;
  final Map<String, int> leaderboard; // userId: count

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

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type,
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
      type: map['type'] ?? 'workouts',
      targetValue: map['targetValue'] ?? 0,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      participants: List<String>.from(map['participants'] ?? []),
      leaderboard: Map<String, int>.from(map['leaderboard'] ?? {}),
    );
  }
}
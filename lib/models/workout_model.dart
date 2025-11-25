import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final DateTime date;
  final List<Exercise> exercises;
  final int duration; // minutes
  final String visibility; // public, friends, private

  WorkoutModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.date,
    required this.exercises,
    required this.duration,
    this.visibility = 'public',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'date': Timestamp.fromDate(date),
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'duration': duration,
      'visibility': visibility,
    };
  }

  factory WorkoutModel.fromMap(Map<String, dynamic> map, String docId) {
    return WorkoutModel(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhoto: map['userPhoto'],
      date: (map['date'] as Timestamp).toDate(),
      exercises: (map['exercises'] as List)
          .map((e) => Exercise.fromMap(e))
          .toList(),
      duration: map['duration'] ?? 0,
      visibility: map['visibility'] ?? 'public',
    );
  }
}

class Exercise {
  final String name;
  final int sets;
  final int reps;
  final double? weight;

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    this.weight,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      name: map['name'] ?? '',
      sets: map['sets'] ?? 0,
      reps: map['reps'] ?? 0,
      weight: map['weight']?.toDouble(),
    );
  }
}
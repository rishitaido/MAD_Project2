import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String? title; // Optional, for naming workouts like "Push Day"
  final DateTime date;
  final List<Exercise> exercises;
  final int duration; // minutes
  final String visibility; // public, private
  final String? preWorkoutPhoto; 
  final String? postWorkoutPhoto; 


  WorkoutModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.title,
    required this.date,
    required this.exercises,
    required this.duration,
    this.visibility = 'public',
    this.preWorkoutPhoto,
    this.postWorkoutPhoto
  });

  // Convert to Firestore-friendly map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'title': title,
      'date': Timestamp.fromDate(date),
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'duration': duration,
      'visibility': visibility,
      'preWorkoutPhoto' : preWorkoutPhoto,
      'postWorkoutPhoto': postWorkoutPhoto,  

    };
  }

  // Build from a raw map + doc ID
  factory WorkoutModel.fromMap(Map<String, dynamic> map, String docId) {
    return WorkoutModel(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhoto: map['userPhoto'],
      title: map['title'], // may be null for older docs
      date: (map['date'] as Timestamp).toDate(),
      exercises: (map['exercises'] as List?)
              ?.map((e) => Exercise.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      duration: _parseInt(map['duration']),
      visibility: map['visibility'] ?? 'public',
      preWorkoutPhoto: map['preWorkoutPhoto'],    
      postWorkoutPhoto: map['postWorkoutPhoto'],  
    );
  }

  // Optional convenience: build directly from a DocumentSnapshot
  factory WorkoutModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return WorkoutModel.fromMap(data, doc.id);
  }

  // Easy way to update parts of a workout immutably
  WorkoutModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhoto,
    String? title,
    DateTime? date,
    List<Exercise>? exercises,
    int? duration,
    String? visibility,
  }) {
    return WorkoutModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhoto: userPhoto ?? this.userPhoto,
      title: title ?? this.title,
      date: date ?? this.date,
      exercises: exercises ?? this.exercises,
      duration: duration ?? this.duration,
      visibility: visibility ?? this.visibility,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class Exercise {
  final String name;
  final String sets;
  final String reps;
  final String? weight;

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
    String setsStr = map['sets']?.toString() ?? '0'; 
    String repsStr = map['reps']?.toString() ?? '0'; 
    String? weightStr = map['weight']?.toString(); 


    return Exercise(
      name: map['name'] ?? '',
      sets: setsStr,
      reps: repsStr,
      weight: weightStr
    );
  }

  Exercise copyWith({
    String? name,
    String? sets,
    String? reps,
    String? weight,
  }) {
    return Exercise(
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
    );
  }
}

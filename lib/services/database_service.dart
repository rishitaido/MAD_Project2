import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/workout_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user data
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return null;
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // Add workout
  Future<void> addWorkout(WorkoutModel workout) async {
    await _firestore.collection('workouts').add(workout.toMap());
  }

  // Get user's workouts
  Stream<List<WorkoutModel>> getUserWorkouts(String userId) {
    return _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get public feed
  Stream<List<WorkoutModel>> getPublicFeed() {
    return _firestore
        .collection('workouts')
        .where('visibility', isEqualTo: 'public')
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
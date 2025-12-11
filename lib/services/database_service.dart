import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/workout_model.dart';
import '../models/post_model.dart';
import '../models/challenge_model.dart';
import '../models/comment_model.dart';

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
  Future<String> addWorkout(WorkoutModel workout) async {
    final docRef = await _firestore.collection('workouts').add(workout.toMap());
    return docRef.id; 
  }

  // Get user's workouts
  Stream<List<WorkoutModel>> getUserWorkouts(String userId) {
    return _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final workouts = snapshot.docs
              .map((doc) => WorkoutModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort in memory instead
          workouts.sort((a, b) => b.date.compareTo(a.date));
          return workouts;
        });
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

  // Create post from workout
  Future<void> createPost({
    required String workoutId,
    required String userId,
    required String userName,
    String? userPhoto,
    String? caption,
  }) async {
    try {
      final post = {
        'workoutId': workoutId,
        'userId': userId,
        'userName': userName,
        'userPhoto': userPhoto,
        'caption': caption,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'commentCount': 0,
      };
      await _firestore.collection('posts').add(post);
      print('✅ Post created successfully');
    } catch (e) {
      print('❌ Error creating post: $e');
      rethrow;
    }
  }

  // Delete post and its comments
  Future<void> deletePost(String postId) async {
    try {
      // Delete the post
      await _firestore.collection('posts').doc(postId).delete();
      
      // Delete all comments for this post
      final comments = await _firestore
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .get();
      
      for (var doc in comments.docs) {
        await doc.reference.delete();
      }
      
      print('✅ Post and comments deleted successfully');
    } catch (e) {
      print('❌ Error deleting post: $e');
      rethrow;
    }
  }

  // Get feed posts
  Stream<List<PostModel>> getFeedPosts() {
    return _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Toggle like on post
  Future<void> toggleLike(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final doc = await postRef.get();

    if (doc.exists) {
      final likes = List<String>.from(doc.data()?['likes'] ?? []);

      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }

      await postRef.update({'likes': likes});
    }
  }

  // Get workout by ID
  Future<WorkoutModel?> getWorkout(String workoutId) async {
    try {
      final doc = await _firestore.collection('workouts').doc(workoutId).get();
      if (doc.exists) {
        return WorkoutModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      print('Error getting workout: $e');
    }
    return null;
  }

  // Get user's workout count
  Future<int> getUserWorkoutCount(String userId) async {
    final snapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.length;
  }

  // Get active challenges
  Stream<List<ChallengeModel>> getActiveChallenges() {
    return _firestore
        .collection('challenges')
        .where('endDate', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Join challenge
  Future<void> joinChallenge(String challengeId, String userId) async {
    final challengeRef = _firestore.collection('challenges').doc(challengeId);
    await challengeRef.update({
      'participants': FieldValue.arrayUnion([userId]),
      'leaderboard.$userId': 0,
    });
  }

  // Leave challenge
  Future<void> leaveChallenge(String challengeId, String userId) async {
    final challengeRef = _firestore.collection('challenges').doc(challengeId);
    await challengeRef.update({
      'participants': FieldValue.arrayRemove([userId]),
      'leaderboard.$userId': FieldValue.delete(),
    });
  }

  // Create challenge
  Future<void> createChallenge(ChallengeModel challenge) async {
    await _firestore.collection('challenges').add(challenge.toMap());
  }

  // Update challenge progress (call this when user logs workout)
  Future<void> updateChallengeProgress(String userId) async {
    final challenges = await _firestore
        .collection('challenges')
        .where('participants', arrayContains: userId)
        .where('endDate', isGreaterThan: Timestamp.now())
        .get();

    for (var doc in challenges.docs) {
      final challenge = ChallengeModel.fromMap(doc.data(), doc.id);
      final currentCount = challenge.leaderboard[userId] ?? 0;
      
      await doc.reference.update({
        'leaderboard.$userId': currentCount + 1,
      });
    }
  }

  Future<void> addComment({
    required String postId,
    required String userId,
    required String userName,
    String? userPhoto,
    required String text,
  }) async {
    try {
      final comment = CommentModel(
        id: '',
        postId: postId,
        userId: userId,
        userName: userName,
        userPhoto: userPhoto,
        text: text,
        timestamp: DateTime.now(),
      );

      await _firestore.collection('comments').add(comment.toMap());

      // Increment comment count on post
      final postRef = _firestore.collection('posts').doc(postId);
      await postRef.update({
        'commentCount': FieldValue.increment(1),
      });

      print('✅ Comment added successfully');
    } catch (e) {
      print('❌ Error adding comment: $e');
      rethrow;
    }
  }

  // Get comments for a post
  Stream<List<CommentModel>> getComments(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Delete comment
  Future<void> deleteComment(String commentId, String postId) async {
    try {
      await _firestore.collection('comments').doc(commentId).delete();

      // Decrement comment count
      final postRef = _firestore.collection('posts').doc(postId);
      await postRef.update({
        'commentCount': FieldValue.increment(-1),
      });
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }

}
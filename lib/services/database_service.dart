import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import '../../models/user_model.dart';
import '../../models/workout_model.dart';
import '../../models/post_model.dart';
import '../../models/challenge_model.dart';
import '../../models/comment_model.dart';
import '../../models/notification_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  //User Methods
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print('❌ Error getting user data: $e');
    }
    return null;
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
      print('✅ User profile updated');
    } catch (e) {
      print('❌ Error updating user profile: $e');
      rethrow;
    }
  }

  // Workout Methods

  Future<String> addWorkout(WorkoutModel workout) async {
    try {
      // Ensure the stored workout "id" matches the Firestore document ID
      final collection = _firestore.collection('workouts');
      final docRef = collection.doc();
      final workoutWithId = workout.copyWith(id: docRef.id);

      await docRef.set(workoutWithId.toMap());
      print('✅ Workout added: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error adding workout: $e');
      rethrow;
    }
  }

  Future<WorkoutModel?> getWorkout(String workoutId) async {
    try {
      final doc = await _firestore.collection('workouts').doc(workoutId).get();
      if (doc.exists) {
        return WorkoutModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      print('❌ Error getting workout: $e');
    }
    return null;
  }

  Stream<List<WorkoutModel>> getUserWorkouts(String userId) {
    return _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final workouts = snapshot.docs
              .map((doc) => WorkoutModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort newest first
          workouts.sort((a, b) => b.date.compareTo(a.date));
          return workouts;
        });
  }

  Future<int> getUserWorkoutCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('workouts')
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting workout count: $e');
      return 0;
    }
  }

  Future<void> deleteWorkout(String workoutId) async {
    try {
      await _firestore.collection('workouts').doc(workoutId).delete();
      print('✅ Workout deleted');
    } catch (e) {
      print('❌ Error deleting workout: $e');
      rethrow;
    }
  }

  // update workout (used by edit flow / history)
  Future<void> updateWorkout(WorkoutModel workout) async {
  try {
    await _firestore
        .collection('workouts')
        .doc(workout.id)
        .update(workout.toMap());
    print('✅ Workout updated');
  } catch (e) {
    print('❌ Error updating workout: $e');
    rethrow;
  }
}


  // Post Method 

  Future<void> createPost({
    required String workoutId,
    required String userId,
    required String userName,
    String? userPhoto,
    String? caption,
    String? title,
  }) async {
    try {
      final post = {
        'workoutId': workoutId,
        'userId': userId,
        'userName': userName,
        'userPhoto': userPhoto,
        'caption': caption,
        'title': title,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'commentCount': 0,
      };
      await _firestore.collection('posts').add(post);
      print('✅ Post created');
    } catch (e) {
      print('❌ Error creating post: $e');
      rethrow;
    }
  }

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

  Future<void> toggleLike(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final doc = await postRef.get();

      if (doc.exists) {
        final likes = List<String>.from(doc.data()?['likes'] ?? []);
        bool isLiking = false;
        
        if (likes.contains(userId)) {
          likes.remove(userId);
        } else {
          likes.add(userId);
          isLiking = true;
        }

        await postRef.update({'likes': likes});

        // Send notification if liking
        if (isLiking) {
          final postUserId = doc.data()?['userId'];
          if (postUserId != null && postUserId != userId) {
            final currentUser = await getUserData(userId);
            if (currentUser != null) {
              await sendNotification(
                recipientId: postUserId,
                senderId: userId,
                senderName: currentUser.name,
                senderPhoto: currentUser.profilePhoto,
                type: NotificationType.like,
                postId: postId,
                message: 'liked your workout',
              );
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error toggling like: $e');
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      // Delete post
      await _firestore.collection('posts').doc(postId).delete();

      // Delete all comments
      final comments = await _firestore
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .get();

      for (var doc in comments.docs) {
        await doc.reference.delete();
      }
      
      // Delete notifications related to this post
      final notifications = await _firestore
          .collection('notifications')
          .where('postId', isEqualTo: postId)
          .get();
          
      for (var doc in notifications.docs) {
        await doc.reference.delete();
      }

      print('✅ Post, comments, and notifications deleted');
    } catch (e) {
      print('❌ Error deleting post: $e');
      rethrow;
    }
  }

  // Comment Methods 
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

      // Increment comment count
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      print('✅ Comment added');

      // Send notification
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final postUserId = postDoc.data()?['userId'];
        if (postUserId != null && postUserId != userId) {
          await sendNotification(
            recipientId: postUserId,
            senderId: userId,
            senderName: userName,
            senderPhoto: userPhoto,
            type: NotificationType.comment,
            postId: postId,
            message: 'commented on your workout: "$text"',
          );
        }
      }
    } catch (e) {
      print('❌ Error adding comment: $e');
      rethrow;
    }
  }

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

  Future<void> deleteComment(String commentId, String postId) async {
    try {
      await _firestore.collection('comments').doc(commentId).delete();

      // Decrement comment count
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(-1),
      });

      print('✅ Comment deleted');
    } catch (e) {
      print('❌ Error deleting comment: $e');
      rethrow;
    }
  }

  // Challenge Methods 
  Stream<List<ChallengeModel>> getActiveChallenges() {
    return _firestore
        .collection('challenges')
        .where('endDate', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChallengeModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> createChallenge(ChallengeModel challenge) async {
    try {
      await _firestore.collection('challenges').add(challenge.toMap());
      print('✅ Challenge created');
    } catch (e) {
      print('❌ Error creating challenge: $e');
      rethrow;
    }
  }

  Future<void> joinChallenge(String challengeId, String userId) async {
    try {
      await _firestore.collection('challenges').doc(challengeId).update({
        'participants': FieldValue.arrayUnion([userId]),
        'leaderboard.$userId': 0,
      });
      print('✅ Joined challenge');
    } catch (e) {
      print('❌ Error joining challenge: $e');
      rethrow;
    }
  }

  Future<void> leaveChallenge(String challengeId, String userId) async {
    try {
      await _firestore.collection('challenges').doc(challengeId).update({
        'participants': FieldValue.arrayRemove([userId]),
        'leaderboard.$userId': FieldValue.delete(),
      });
      print('✅ Left challenge');
    } catch (e) {
      print('❌ Error leaving challenge: $e');
      rethrow;
    }
  }

  Future<void> updateChallengeProgress(String userId) async {
    try {
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
      
      if (challenges.docs.isNotEmpty) {
        print('✅ Challenge progress updated');
      }
    } catch (e) {
      print('❌ Error updating challenge progress: $e');
    }
  }

  // Storage for Pictures  
  Future<String> uploadWorkoutPhoto(String userId, File imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('workout_photos')
          .child(userId)
          .child('$timestamp.jpg');

      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      
      print('✅ Photo uploaded');
      return url;
    } catch (e) {
      print('❌ Error uploading photo: $e');
      rethrow;
    }
  }

  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('profile_photos')
          .child(userId)
          .child('$timestamp.jpg');

      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      
      print('✅ Profile photo uploaded');
      return url;
    } catch (e) {
      print('❌ Error uploading profile photo: $e');
      rethrow;
    }
  }

  // Workout Streak Calculation
  Future<int> getUserWorkoutStreak(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('workouts')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return 0;
      }

      final workouts = snapshot.docs
          .map((doc) => WorkoutModel.fromMap(doc.data(), doc.id))
          .toList();

      // Get unique workout dates
      final workoutDates = workouts
          .map((w) => DateTime(w.date.year, w.date.month, w.date.day))
          .toSet()
          .toList();
      
      workoutDates.sort((a, b) => b.compareTo(a)); // Sort descending

      if (workoutDates.isEmpty) {
        return 0;
      }

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final yesterdayDate = todayDate.subtract(const Duration(days: 1));

      // Check if the most recent workout was today or yesterday
      // If it's older than yesterday, streak is broken
      final mostRecentDate = workoutDates.first;
      if (mostRecentDate.isBefore(yesterdayDate)) {
        return 0;
      }

      // Count consecutive days
      int streak = 1;
      for (int i = 1; i < workoutDates.length; i++) {
        final currentDate = workoutDates[i];
        final previousDate = workoutDates[i - 1];
        final difference = previousDate.difference(currentDate).inDays;

        if (difference == 1) {
          // Consecutive day
          streak++;
        } else {
          // Gap found, break the streak
          break;
        }
      }

      return streak;
    } catch (e) {
      print('❌ Error calculating workout streak: $e');
      return 0;
    }
  }

  // Follower Methods
  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      final batch = _firestore.batch();
      
      // Add to target's followers
      final targetRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId);
      
      batch.set(targetRef, {'timestamp': FieldValue.serverTimestamp()});

      // Add to current's following
      final currentRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId);

      batch.set(currentRef, {'timestamp': FieldValue.serverTimestamp()});

      await batch.commit();
      print('✅ Followed user');

      // Send notification
      final currentUser = await getUserData(currentUserId);
      if (currentUser != null) {
        await sendNotification(
          recipientId: targetUserId,
          senderId: currentUserId,
          senderName: currentUser.name,
          senderPhoto: currentUser.profilePhoto,
          type: NotificationType.follow,
          message: 'started following you',
        );
      }
    } catch (e) {
      print('❌ Error following user: $e');
      rethrow;
    }
  }

  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      final batch = _firestore.batch();

      final targetRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId);

      batch.delete(targetRef);

      final currentRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId);
      
      batch.delete(currentRef);

      await batch.commit();
      print('✅ Unfollowed user');
    } catch (e) {
      print('❌ Error unfollowing user: $e');
      rethrow;
    }
  }

  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      print('❌ Error checking follow status: $e');
      return false;
    }
  }

  Future<int> getFollowerCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Error getting follower count: $e');
      return 0;
    }
  }

  Future<int> getFollowingCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Error getting following count: $e');
      return 0;
    }
  }

  Future<List<UserModel>> getFollowers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .get();
      
      final List<UserModel> followers = [];
      for (var doc in snapshot.docs) {
        final userDoc = await _firestore.collection('users').doc(doc.id).get();
        if (userDoc.exists) {
          followers.add(UserModel.fromMap(userDoc.data()!));
        }
      }
      return followers;
    } catch (e) {
      print('❌ Error getting followers: $e');
      return [];
    }
  }

  // Notification Methods
  Future<void> sendNotification({
    required String recipientId,
    required String senderId,
    required String senderName,
    String? senderPhoto,
    required NotificationType type,
    String? postId,
    required String message,
  }) async {
    if (recipientId == senderId) return; // Don't verify self

    try {
      final notification = NotificationModel(
        id: '',
        recipientId: recipientId,
        senderId: senderId,
        senderName: senderName,
        senderPhoto: senderPhoto,
        type: type,
        postId: postId,
        message: message,
        timestamp: DateTime.now(),
      );

      await _firestore.collection('notifications').add(notification.toMap());
      print('✅ Notification sent');
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String workoutId;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String? caption;
  final String? title;
  final DateTime timestamp;
  final List<String> likes;
  final int commentCount;

  PostModel({
    required this.id,
    required this.workoutId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.caption,
    this.title,
    required this.timestamp,
    required this.likes,
    this.commentCount = 0,
  });

  bool isLikedBy(String userId) => likes.contains(userId);

  Map<String, dynamic> toMap() {
    return {
      'workoutId': workoutId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'caption': caption,
      'title': title,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'commentCount': commentCount,
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map, String docId) {
    return PostModel(
      id: docId,
      workoutId: map['workoutId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhoto: map['userPhoto'],
      caption: map['caption'],
      title: map['title'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      likes: List<String>.from(map['likes'] ?? []),
      commentCount: map['commentCount'] ?? 0,
    );
  }
}
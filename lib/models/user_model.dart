import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? profilePhoto;
  final String? bio;
  final double? currentWeight;
  final double? targetWeight;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.profilePhoto,
    this.bio,
    this.currentWeight,
    this.targetWeight,
    required this.createdAt,
  });

  // Convert to map for firebase
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'profilePhoto': profilePhoto,
      'bio': bio,
      'currentWeight': currentWeight,
      'targetWeight': targetWeight,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Convert into map from firebase
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      profilePhoto: map['profilePhoto'],
      bio: map['bio'],
      currentWeight: map['currentWeight']?.toDouble(),
      targetWeight: map['targetWeight']?.toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
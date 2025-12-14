import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { like, comment, follow }

class NotificationModel {
  final String id;
  final String recipientId;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final NotificationType type;
  final String? postId;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.type,
    this.postId,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'type': type.toString().split('.').last,
      'postId': postId,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationModel(
      id: docId,
      recipientId: map['recipientId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderPhoto: map['senderPhoto'],
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => NotificationType.like,
      ),
      postId: map['postId'],
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
    );
  }
}

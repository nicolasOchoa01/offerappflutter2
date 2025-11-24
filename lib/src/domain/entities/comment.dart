import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/src/domain/entities/user.dart';

@immutable
class Comment {
  final String id;
  final String postId;
  final String userId;
  final User? user;
  final String text;
  final Timestamp? timestamp;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    this.user,
    required this.text,
    this.timestamp,
  });

  factory Comment.fromMap(Map<String, dynamic> map, String documentId) {
    return Comment(
      id: documentId,
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      user: map['user'] != null ? User.fromMap(map['user']) : null,
      text: map['text'] ?? '',
      timestamp: map['timestamp'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'user': user?.toMap(),
      'text': text,
      'timestamp': timestamp,
    };
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    User? user,
    String? text,
    Timestamp? timestamp,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      user: user ?? this.user,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/src/domain/entities/score.dart';
import 'package:myapp/src/domain/entities/user.dart';

@immutable
class Post {
  final String id;
  final String userId; // Added for consistency and easier access
  final String description;
  final String imageUrl;
  final String location;
  final double latitude;
  final double longitude;
  final String category;
  final double price;
  final double discountPrice;
  final User? user;
  final List<Score> scores;
  final Timestamp? timestamp;
  final String status;
  final String store;

  const Post({
    required this.id,
    required this.userId, // Made required
    this.description = '',
    this.imageUrl = '',
    this.location = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.category = '',
    this.price = 0.0,
    this.discountPrice = 0.0,
    this.user,
    this.scores = const [],
    this.timestamp,
    this.status = 'activa',
    this.store = '',
  });

  factory Post.fromMap(Map<String, dynamic> map, String documentId) {
    return Post(
      id: documentId,
      userId: map['userId'] ?? '', // Read userId
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      location: map['location'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      discountPrice: (map['discountPrice'] as num?)?.toDouble() ?? 0.0,
      user: map['user'] != null ? User.fromMap(map['user']) : null,
      scores: (map['scores'] as List<dynamic>?)
              ?.map((scoreMap) => Score.fromMap(scoreMap))
              .toList() ??
          [],
      timestamp: map['timestamp'] as Timestamp?,
      status: map['status'] ?? 'activa',
      store: map['store'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId, // Write userId
      'description': description,
      'imageUrl': imageUrl,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'price': price,
      'discountPrice': discountPrice,
      'user': user?.toMap(),
      'scores': scores.map((score) => score.toMap()).toList(),
      'timestamp': timestamp,
      'status': status,
      'store': store,
    };
  }

  Post copyWith({
    String? id,
    String? userId,
    String? description,
    String? imageUrl,
    String? location,
    double? latitude,
    double? longitude,
    String? category,
    double? price,
    double? discountPrice,
    User? user,
    List<Score>? scores,
    Timestamp? timestamp,
    String? status,
    String? store,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      price: price ?? this.price,
      discountPrice: discountPrice ?? this.discountPrice,
      user: user ?? this.user,
      scores: scores ?? this.scores,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      store: store ?? this.store,
    );
  }
}

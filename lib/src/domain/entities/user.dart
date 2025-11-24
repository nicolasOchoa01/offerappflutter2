import 'package:flutter/foundation.dart';

@immutable
class User {
  final String id; // Standardized to use 'id'
  final String username;
  final String email;
  final String? profileImageUrl; // Made nullable for consistency
  final List<String> followers;
  final List<String> following;
  final List<String> favorites;

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.profileImageUrl,
    this.followers = const [],
    this.following = const [],
    this.favorites = const [],
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '', // Reads 'id'
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      profileImageUrl: map['profileImageUrl'], // Can be null
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      favorites: List<String>.from(map['favorites'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Writes 'id'
      'username': username,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'followers': followers,
      'following': following,
      'favorites': favorites,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? profileImageUrl,
    List<String>? followers,
    List<String>? following,
    List<String>? favorites,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      favorites: favorites ?? this.favorites,
    );
  }
}

import 'package:flutter/foundation.dart';

@immutable
class User {
  final String uid;
  final String username;
  final String email;
  final String profileImageUrl;
  final List<String> followers;
  final List<String> following;
  final List<String> favorites;

  const User({
    required this.uid,
    required this.username,
    required this.email,
    this.profileImageUrl = '',
    this.followers = const [],
    this.following = const [],
    this.favorites = const [],
  });

  // Factory constructor para crear una instancia de User desde un mapa (ideal para Firestore)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      favorites: List<String>.from(map['favorites'] ?? []),
    );
  }

  // Método para convertir una instancia de User a un mapa
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'followers': followers,
      'following': following,
      'favorites': favorites,
    };
  }

  // Método copyWith para crear una copia del objeto con valores actualizados
  User copyWith({
    String? uid,
    String? username,
    String? email,
    String? profileImageUrl,
    List<String>? followers,
    List<String>? following,
    List<String>? favorites,
  }) {
    return User(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      favorites: favorites ?? this.favorites,
    );
  }
}

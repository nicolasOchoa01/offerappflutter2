import 'package:flutter/foundation.dart';

@immutable
class Score {
  final String userId;
  final int value; 

  const Score({
    required this.userId,
    required this.value,
  });

  factory Score.fromMap(Map<String, dynamic> map) {
    return Score(
      userId: map['userId'] ?? '',
      value: map['value'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'value': value,
    };
  }

  Score copyWith({
    String? userId,
    int? value,
  }) {
    return Score(
      userId: userId ?? this.userId,
      value: value ?? this.value,
    );
  }
}

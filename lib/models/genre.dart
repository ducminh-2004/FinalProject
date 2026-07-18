import 'package:flutter/material.dart';

class Genre {
  final String id;
  final String name;
  final int colorValue;
  final String? description;
  final String? imageUrl; // Thêm imageUrl

  const Genre({
    required this.id,
    required this.name,
    required this.colorValue,
    this.description,
    this.imageUrl,
  });

  Color get color => Color(colorValue);
}
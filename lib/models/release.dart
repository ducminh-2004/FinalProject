import 'package:flutter/material.dart';

class Release {
  final String id;
  final String type;
  final String title;
  final String artist;
  final Color coverColor;

  const Release({
    required this.id,
    required this.type,
    required this.title,
    required this.artist,
    required this.coverColor,
  });
}
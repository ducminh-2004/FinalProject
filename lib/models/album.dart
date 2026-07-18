import 'package:cloud_firestore/cloud_firestore.dart';
import 'song.dart';

class Album {
  final String id;
  final String title;
  final String artist;
  final String? artistId;
  final String? coverUrl;
  final String? releaseYear;
  final List<Song> songs;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    this.artistId,
    this.coverUrl,
    this.releaseYear,
    this.songs = const [],
  });

  factory Album.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Album(
      id: doc.id,
      title: data['title'] ?? '',
      artist: data['artist'] ?? '',
      artistId: data['artistId'],
      coverUrl: data['coverUrl'],
      releaseYear: data['releaseYear']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'artist': artist,
      'artistId': artistId,
      'coverUrl': coverUrl,
      'releaseYear': releaseYear,
    };
  }
}

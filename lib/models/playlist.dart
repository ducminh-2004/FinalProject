import 'package:cloud_firestore/cloud_firestore.dart';

class Playlist {
  final String id;
  final String title;
  final String? coverUrl;
  final String? ownerId;
  final String? ownerName;
  final List<String> songIds;
  final bool isFeatured;
  final DateTime? createdAt;

  const Playlist({
    required this.id,
    required this.title,
    this.coverUrl,
    this.ownerId,
    this.ownerName,
    this.songIds = const [],
    this.isFeatured = false,
    this.createdAt,
  });

  factory Playlist.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Playlist(
      id: doc.id,
      title: data['title'] ?? '',
      coverUrl: data['coverUrl'],
      ownerId: data['ownerId'],
      ownerName: data['ownerName'],
      songIds: List<String>.from(data['songIds'] ?? []),
      isFeatured: data['isFeatured'] ?? false,
      createdAt: data['createdAt']?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'coverUrl': coverUrl,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'songIds': songIds,
      'isFeatured': isFeatured,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  Playlist copyWith({
    String? id,
    String? title,
    String? coverUrl,
    String? ownerId,
    String? ownerName,
    List<String>? songIds,
    bool? isFeatured,
    DateTime? createdAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      songIds: songIds ?? this.songIds,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

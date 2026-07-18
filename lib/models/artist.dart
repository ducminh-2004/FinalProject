import 'package:cloud_firestore/cloud_firestore.dart';
import 'song.dart';
import 'album.dart';

class Artist {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final int? monthlyListeners;
  final int? followerCount;
  final bool? isVerified;
  final List<String>? genres;
  final List<String>? songIds;
  final List<String>? albumIds;
  final String? socialLinks;
  final DateTime? createdAt;

  const Artist({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.monthlyListeners,
    this.followerCount,
    this.isVerified,
    this.genres,
    this.songIds,
    this.albumIds,
    this.socialLinks,
    this.createdAt,
  });

  factory Artist.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return Artist(id: doc.id, name: '');
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return Artist(
      id: doc.id,
      name: data['name'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      bio: data['bio'] as String?,
      monthlyListeners: parseInt(data['monthlyListeners']),
      followerCount: parseInt(data['followerCount']),
      isVerified: data['isVerified'] as bool?,
      genres: (data['genres'] as List?)?.cast<String>(),
      songIds: (data['songIds'] as List?)?.cast<String>(),
      albumIds: (data['albumIds'] as List?)?.cast<String>(),
      socialLinks: data['socialLinks'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'monthlyListeners': monthlyListeners,
      'followerCount': followerCount,
      'isVerified': isVerified,
      'genres': genres,
      'songIds': songIds,
      'albumIds': albumIds,
      'socialLinks': socialLinks,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  Artist copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? bio,
    int? monthlyListeners,
    int? followerCount,
    bool? isVerified,
    List<String>? genres,
    List<String>? songIds,
    List<String>? albumIds,
    String? socialLinks,
    DateTime? createdAt,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      monthlyListeners: monthlyListeners ?? this.monthlyListeners,
      followerCount: followerCount ?? this.followerCount,
      isVerified: isVerified ?? this.isVerified,
      genres: genres ?? this.genres,
      songIds: songIds ?? this.songIds,
      albumIds: albumIds ?? this.albumIds,
      socialLinks: socialLinks ?? this.socialLinks,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Search result types
enum SearchResultType { song, artist, album, playlist }

class SearchResult {
  final SearchResultType type;
  final dynamic data;

  const SearchResult({required this.type, required this.data});
}

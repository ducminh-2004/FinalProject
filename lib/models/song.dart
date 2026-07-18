import 'package:cloud_firestore/cloud_firestore.dart';

class Song {
  final String id;
  final String title;
  final List<String> artists; // Đổi từ String sang List<String>
  final List<String> artistIds; // Đổi từ String? sang List<String>
  final String? coverUrl;
  final String? audioUrl;
  final int? durationMs;
  final bool? isLiked;
  final List<String> genres; 
  final List<String> genreIds;

  const Song({
    required this.id,
    required this.title,
    this.artists = const [],
    this.artistIds = const [],
    this.coverUrl,
    this.audioUrl,
    this.durationMs,
    this.isLiked,
    this.genres = const [],
    this.genreIds = const [],
  });

  // Getter để lấy tên nghệ sĩ chính (hoặc chuỗi kết hợp) để hiển thị nhanh
  String get artistDisplay => artists.isNotEmpty ? artists.join(', ') : 'Unknown Artist';

  // Hỗ trợ thuộc tính cũ để tránh lỗi compile ở những chỗ chưa sửa hết
  String get artist => artistDisplay;

  factory Song.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return Song(id: doc.id, title: '');
    }

    // Handle artists (List or old String)
    List<String> artistsList = [];
    if (data['artists'] is List) {
      artistsList = (data['artists'] as List).cast<String>();
    } else if (data['artist'] is String) {
      artistsList = [data['artist'] as String];
    }

    // Handle artistIds (List or old String)
    List<String> artistIdsList = [];
    if (data['artistIds'] is List) {
      artistIdsList = (data['artistIds'] as List).cast<String>();
    } else if (data['artistId'] is String) {
      artistIdsList = [data['artistId'] as String];
    }

    // Handle genres
    List<String> genresList = [];
    if (data['genres'] is List) {
      genresList = (data['genres'] as List).cast<String>();
    } else if (data['genre'] is String) {
      genresList = [data['genre'] as String];
    }

    // Handle genreIds
    List<String> genreIdsList = [];
    if (data['genreIds'] is List) {
      genreIdsList = (data['genreIds'] as List).cast<String>();
    }

    return Song(
      id: doc.id,
      title: data['title'] as String? ?? '',
      artists: artistsList,
      artistIds: artistIdsList,
      coverUrl: data['coverUrl'] as String?,
      audioUrl: data['audioUrl'] as String?,
      durationMs: data['durationMs'] as int?,
      isLiked: data['isLiked'] as bool?,
      genres: genresList,
      genreIds: genreIdsList,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'artists': artists,
      'artistIds': artistIds,
      'coverUrl': coverUrl,
      'audioUrl': audioUrl,
      'durationMs': durationMs,
      'isLiked': isLiked,
      'genres': genres,
      'genreIds': genreIds,
    };
  }

  Song copyWith({
    String? id,
    String? title,
    List<String>? artists,
    List<String>? artistIds,
    String? coverUrl,
    String? audioUrl,
    int? durationMs,
    bool? isLiked,
    List<String>? genres,
    List<String>? genreIds,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artists: artists ?? this.artists,
      artistIds: artistIds ?? this.artistIds,
      coverUrl: coverUrl ?? this.coverUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      durationMs: durationMs ?? this.durationMs,
      isLiked: isLiked ?? this.isLiked,
      genres: genres ?? this.genres,
      genreIds: genreIds ?? this.genreIds,
    );
  }

  static Song fromFirestoreMap(Map<String, dynamic> data) {
    // Handle list conversions
    List<String> artistsList = [];
    if (data['artists'] is List) artistsList = (data['artists'] as List).cast<String>();
    else if (data['artist'] is String) artistsList = [data['artist'] as String];

    List<String> artistIdsList = [];
    if (data['artistIds'] is List) artistIdsList = (data['artistIds'] as List).cast<String>();
    else if (data['artistId'] is String) artistIdsList = [data['artistId'] as String];

    return Song(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      artists: artistsList,
      artistIds: artistIdsList,
      coverUrl: data['coverUrl'],
      audioUrl: data['audioUrl'],
      durationMs: data['durationMs'],
      genres: (data['genres'] as List?)?.cast<String>() ?? [],
      genreIds: (data['genreIds'] as List?)?.cast<String>() ?? [],
    );
  }
}

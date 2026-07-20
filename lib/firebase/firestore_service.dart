import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/genre.dart';
import '../models/release.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create user document in Firestore
  static Future<void> createUserDocument({
    required String userId,
    required String email,
    String? displayName,
    bool isAdmin = false,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'email': email,
        'displayName': displayName ?? '',
        'role': isAdmin ? 'admin' : 'user',
        'isAdmin': isAdmin,
        'isBanned': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Songs
  static Future<List<Song>> getSongs({int limit = 20}) async {
    try {
      final snapshot = await _db.collection('songs')
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) => Song.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting songs: $e');
      return [];
    }
  }

  static Future<Song?> getSongById(String id) async {
    try {
      final doc = await _db.collection('songs').doc(id).get();
      if (!doc.exists) return null;
      
      return Song.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting song: $e');
      return null;
    }
  }

  // Search songs by query (title, artist, or genre)
  static Future<List<Song>> searchSongs(String query) async {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    final snapshot = await _db.collection('songs').get();
    
    final allSongs = snapshot.docs.map((doc) => Song.fromFirestore(doc)).where((song) =>
        song.title.toLowerCase().contains(lowerQuery) ||
        song.artist.toLowerCase().contains(lowerQuery) ||
        song.genres.any((g) => g.toLowerCase().contains(lowerQuery))).toList();

    // Logic gộp bài hát trùng lặp (Dựa trên tên + nghệ sĩ)
    final Map<String, Song> uniqueSongs = {};
    for (var song in allSongs) {
      final key = '${song.title.toLowerCase()}_${song.artist.toLowerCase()}';
      // Nếu chưa có hoặc bản ghi hiện tại có coverUrl (ưu tiên bản ghi đẹp) thì lưu/ghi đè
      if (!uniqueSongs.containsKey(key) || (song.coverUrl != null && song.coverUrl!.isNotEmpty)) {
        uniqueSongs[key] = song;
      }
    }
    
    return uniqueSongs.values.toList();
  }

  // Search artists by query
  static Future<List<Artist>> searchArtists(String query) async {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    final snapshot = await _db.collection('artists').get();
    
    return snapshot.docs
        .map((doc) => Artist.fromFirestore(doc))
        .where((artist) =>
            artist.name.toLowerCase().contains(lowerQuery) ||
            (artist.genres?.any((g) => g.toLowerCase().contains(lowerQuery)) ?? false))
        .toList();
  }

  // Search songs by genre
  static Future<List<Song>> getSongsByGenre(String genreId) async {
    try {
      // Tìm bài hát theo genreIds (ID của thể loại)
      final snapshot = await _db.collection('songs')
          .where('genreIds', arrayContains: genreId)
          .get();
      
      return snapshot.docs.map((doc) => Song.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting songs by genre: $e');
      return [];
    }
  }

  // Liked Songs - Separate collection
  static Future<List<String>> getLikedSongIds(String userId) async {
    try {
      final snapshot = await _db.collection('liked_songs')
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.map((doc) => doc['songId'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> toggleLikeSong(String userId, String songId) async {
    final docId = '${userId}_$songId';
    final docRef = _db.collection('liked_songs').doc(docId);
    final doc = await docRef.get();
    
    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'userId': userId,
        'songId': songId,
        'likedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ==================== FOLLOW ARTISTS ====================

  // Get user's followed artist IDs
  static Future<List<String>> getFollowedArtistIds(String userId) async {
    try {
      final snapshot = await _db.collection('followed_artists')
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.map((doc) => doc['artistId'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  // Toggle follow/unfollow artist
  static Future<bool> toggleFollowArtist(String userId, String artistId) async {
    final docId = '${userId}_$artistId';
    final docRef = _db.collection('followed_artists').doc(docId);
    final doc = await docRef.get();
    
    if (doc.exists) {
      await docRef.delete();
      await _decreaseArtistFollowerCount(artistId);
      return false;
    } else {
      await docRef.set({
        'userId': userId,
        'artistId': artistId,
        'followedAt': FieldValue.serverTimestamp(),
      });
      await _increaseArtistFollowerCount(artistId);
      return true;
    }
  }

  // Check if user is following an artist
  static Future<bool> isFollowingArtist(String userId, String artistId) async {
    final docId = '${userId}_$artistId';
    final doc = await _db.collection('followed_artists').doc(docId).get();
    return doc.exists;
  }

  // Get user's followed artists
  static Future<List<Artist>> getFollowedArtists(String userId) async {
    final artistIds = await getFollowedArtistIds(userId);
    if (artistIds.isEmpty) return [];
    
    final artists = <Artist>[];
    for (final id in artistIds) {
      final artist = await getArtistById(id);
      if (artist != null) artists.add(artist);
    }
    return artists;
  }

  // Get artist by ID
  static Future<Artist?> getArtistById(String id) async {
    try {
      final doc = await _db.collection('artists').doc(id).get();
      if (!doc.exists) return null;

      return Artist.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting artist: $e');
      return null;
    }
  }

  // Helper to increase follower count
  static Future<void> _increaseArtistFollowerCount(String artistId) async {
    await _db.collection('artists').doc(artistId).update({
      'followerCount': FieldValue.increment(1),
    });
  }

  // Helper to decrease follower count
  static Future<void> _decreaseArtistFollowerCount(String artistId) async {
    final doc = await _db.collection('artists').doc(artistId).get();
    final currentCount = doc['followerCount'] ?? 0;
    if (currentCount > 0) {
      await _db.collection('artists').doc(artistId).update({
        'followerCount': FieldValue.increment(-1),
      });
    }
  }

  // Albums
  static Future<List<Album>> getAlbums({int limit = 10}) async {
    try {
      final snapshot = await _db.collection('albums')
          .limit(limit)
          .get();
      
      final albums = <Album>[];
      for (final doc in snapshot.docs) {
        final songIds = List<String>.from(doc['songIds'] ?? []);
        final songs = await getSongsByIds(songIds);
        albums.add(Album(
          id: doc.id,
          title: doc['title'] ?? '',
          artist: doc['artist'] ?? '',
          coverUrl: doc['coverUrl'] ?? '',
          songs: songs,
        ));
      }
      
      return albums;
    } catch (e) {
      debugPrint('Error getting albums: $e');
      return [];
    }
  }

  static Future<Album?> getAlbumById(String id) async {
    final doc = await _db.collection('albums').doc(id).get();
    if (!doc.exists) return null;
    
    final songIds = List<String>.from(doc['songIds'] ?? []);
    final songs = await getSongsByIds(songIds);
    
    return Album(
      id: doc['id'] ?? doc.id,
      title: doc['title'] ?? '',
      artist: doc['artist'] ?? '',
      coverUrl: doc['coverUrl'] ?? '',
      songs: songs,
    );
  }

  // Artists
  static Future<List<Artist>> getArtists({int limit = 10}) async {
    try {
      final snapshot = await _db.collection('artists')
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) => Artist.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting artists: $e');
      return [];
    }
  }

  // Playlists
  static Future<List<Playlist>> getPlaylists({int limit = 10}) async {
    try {
      final snapshot = await _db.collection('playlists')
          .limit(limit)
          .get();
      
      final playlists = <Playlist>[];
      for (final doc in snapshot.docs) {
        final songIds = List<String>.from(doc['songIds'] ?? []);
        playlists.add(Playlist(
          id: doc.id,
          title: doc['title'] ?? '',
          coverUrl: doc['coverUrl'] ?? '',
          songIds: songIds,
        ));
      }
      
      return playlists;
    } catch (e) {
      debugPrint('Error getting playlists: $e');
      return [];
    }
  }

  // Genres
  static Future<List<Genre>> getGenres({int limit = 10}) async {
    try {
      final snapshot = await _db.collection('genres')
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) => Genre(
        id: doc.id,
        name: doc['name'] ?? '',
        colorValue: doc['colorValue'] ?? 0xFF1DB954,
        description: doc.data().containsKey('description') ? doc['description']?.toString() : null,
        imageUrl: doc.data().containsKey('imageUrl') ? doc['imageUrl']?.toString() : null,
      )).toList();
    } catch (e) {
      debugPrint('Error getting genres: $e');
      return [];
    }
  }

  // Releases
  static Future<List<Release>> getReleases({int limit = 10}) async {
    try {
      final snapshot = await _db.collection('releases')
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) => Release(
        id: doc.id,
        type: doc['type'] ?? 'Single',
        title: doc['title'] ?? '',
        artist: doc['artist'] ?? '',
        coverColor: Color(doc['coverColor'] ?? 0xFF1DB954),
      )).toList();
    } catch (e) {
      debugPrint('Error getting releases: $e');
      return [];
    }
  }

  // Helper
  static Future<List<Song>> getSongsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    final songs = <Song>[];
    for (final id in ids) {
      final song = await getSongById(id);
      if (song != null) songs.add(song);
    }
    
    return songs;
  }

  // Add song to playlist
  static Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await _db.collection('playlists').doc(playlistId).update({
      'songIds': FieldValue.arrayUnion([songId]),
    });
  }

  // Remove song from playlist
  static Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await _db.collection('playlists').doc(playlistId).update({
      'songIds': FieldValue.arrayRemove([songId]),
    });
  }

  // Create new playlist
  static Future<String> createPlaylist({
    required String userId,
    required String title,
    String? coverUrl,
  }) async {
    final docRef = await _db.collection('playlists').add({
      'userId': userId,
      'title': title,
      'coverUrl': coverUrl ?? '',
      'songIds': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Get user's playlists
  static Future<List<Playlist>> getUserPlaylists(String userId) async {
    try {
      final snapshot = await _db.collection('playlists')
          .where('userId', isEqualTo: userId)
          .get();
      
      return snapshot.docs.map((doc) => Playlist.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting user playlists: $e');
      return [];
    }
  }

  // Keep playlist metadata (including song counts) in sync with Firestore.
  static Stream<List<Playlist>> watchUserPlaylists(String userId) {
    return _db
        .collection('playlists')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Playlist.fromFirestore(doc)).toList());
  }

  // Get songs from playlist
  static Future<List<Song>> getSongsFromPlaylist(String playlistId) async {
    final doc = await _db.collection('playlists').doc(playlistId).get();
    if (!doc.exists) return [];
    
    final songIds = List<String>.from(doc['songIds'] ?? []);
    return await getSongsByIds(songIds);
  }

  // Update playlist
  static Future<void> updatePlaylist(String playlistId, Map<String, dynamic> data) async {
    await _db.collection('playlists').doc(playlistId).update(data);
  }

  // Update playlist title (legacy)
  static Future<void> updatePlaylistTitle(String playlistId, String newTitle) async {
    await updatePlaylist(playlistId, {'title': newTitle});
  }

  // Delete playlist
  static Future<void> deletePlaylist(String playlistId) async {
    await _db.collection('playlists').doc(playlistId).delete();
  }

  // ==================== ADMIN FUNCTIONS ====================

  // Check if user is admin
  static Future<bool> checkUserIsAdmin(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      return doc['role'] == 'admin' || doc['isAdmin'] == true;
    } catch (e) {
      debugPrint('Error checking admin: $e');
      return false;
    }
  }

  // Get full role status for a user (role, isAdmin, pending artist, artistId)
  static Future<Map<String, dynamic>> getUserRoleStatus(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return {'role': 'user'};
      final data = doc.data() ?? {};
      return {
        'role': data['role'] ?? 'user',
        'isAdmin': data['isAdmin'] == true,
        'isPendingArtist': data['isPendingArtist'] == true,
        'artistId': data['artistId'],
      };
    } catch (e) {
      debugPrint('Error getting role status: $e');
      return {'role': 'user'};
    }
  }

  // Set user role
  static Future<void> setUserRole(String userId, String role) async {
    await _db.collection('users').doc(userId).update({
      'role': role,
      'isAdmin': role == 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get all users
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snapshot = await _db.collection('users').get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting users: $e');
      return [];
    }
  }

  // Delete user
  static Future<void> deleteUser(String userId) async {
    // Delete user's liked songs reference
    await _db.collection('users').doc(userId).delete();
    // Note: In production, you might want to delete auth user as well via Admin SDK
  }

  // Ban/unban user
  static Future<void> setUserBanned(String userId, bool banned) async {
    await _db.collection('users').doc(userId).update({
      'isBanned': banned,
      'bannedAt': banned ? FieldValue.serverTimestamp() : null,
    });
  }

  // ==================== ADMIN: SONGS ====================

  // Create song
  static Future<String> createSong({
    required String title,
    required List<String> artists, // Đổi sang List
    List<String>? artistIds, // Đổi sang List
    String? coverUrl,
    String? audioUrl,
    int? durationMs,
    List<String>? genres,
    List<String>? genreIds,
  }) async {
    final docRef = await _db.collection('songs').add({
      'title': title,
      'artists': artists,
      'artistIds': artistIds ?? [],
      'coverUrl': coverUrl ?? '',
      'audioUrl': audioUrl ?? '',
      'durationMs': durationMs ?? 0,
      'genres': genres ?? [],
      'genreIds': genreIds ?? [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Update song
  static Future<void> updateSong(String songId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('songs').doc(songId).update(data);
  }

  // Delete song
  static Future<void> deleteSong(String songId) async {
    await _db.collection('songs').doc(songId).delete();
  }

  // ==================== ADMIN: ARTISTS ====================

  // Create artist
  static Future<String> createArtist({
    required String name,
    String? avatarUrl,
    String? bio,
    List<String>? genres,
    int? monthlyListeners,
  }) async {
    final docRef = await _db.collection('artists').add({
      'name': name,
      'avatarUrl': avatarUrl ?? '',
      'bio': bio ?? '',
      'genres': genres ?? [],
      'monthlyListeners': monthlyListeners ?? 0,
      'followerCount': 0,
      'isVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Update artist
  static Future<void> updateArtist(String artistId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('artists').doc(artistId).update(data);
  }

  // Delete artist
  static Future<void> deleteArtist(String artistId) async {
    await _db.collection('artists').doc(artistId).delete();
  }

  // ==================== ADMIN: ALBUMS ====================

  // Create album
  static Future<String> createAlbum({
    required String title,
    required String artist,
    String? artistId,
    String? coverUrl,
    List<String>? songIds,
    String? releaseYear,
  }) async {
    final docRef = await _db.collection('albums').add({
      'title': title,
      'artist': artist,
      'artistId': artistId,
      'coverUrl': coverUrl ?? '',
      'songIds': songIds ?? [],
      'releaseYear': releaseYear,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Create an album together with a batch of new songs.
  // Each song map: {title, coverUrl, audioUrl, genres}. Returns album id.
  static Future<String> createAlbumWithSongs({
    required String title,
    required String artist,
    String? artistId,
    String? coverUrl,
    String? releaseYear,
    required List<Map<String, dynamic>> songs,
  }) async {
    final List<String> artistsList = [artist];
    final List<String> artistIds = artistId != null ? [artistId] : [];

    final songIds = <String>[];
    for (final s in songs) {
      final songId = await createSong(
        title: s['title'] as String? ?? '',
        artists: artistsList,
        artistIds: artistIds,
        coverUrl: (s['coverUrl'] as String?)?.isNotEmpty == true
            ? s['coverUrl'] as String
            : coverUrl,
        audioUrl: s['audioUrl'] as String?,
        genres: (s['genres'] as List?)?.cast<String>() ?? [],
      );
      songIds.add(songId);
    }

    return createAlbum(
      title: title,
      artist: artist,
      artistId: artistId,
      coverUrl: coverUrl,
      songIds: songIds,
      releaseYear: releaseYear,
    );
  }

  // Update album
  static Future<void> updateAlbum(String albumId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('albums').doc(albumId).update(data);
  }

  // Delete album
  static Future<void> deleteAlbum(String albumId) async {
    await _db.collection('albums').doc(albumId).delete();
  }

  // ==================== ADMIN: GENRES ====================

  // Create genre
  static Future<String> createGenre({
    required String name,
    int? colorValue,
    String? description,
    String? imageUrl,
  }) async {
    final docRef = await _db.collection('genres').add({
      'name': name,
      'colorValue': colorValue ?? 0xFF1DB954,
      'description': description ?? '',
      'imageUrl': imageUrl ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Update genre
  static Future<void> updateGenre(String genreId, Map<String, dynamic> data) async {
    await _db.collection('genres').doc(genreId).update(data);
  }

  // Delete genre
  static Future<void> deleteGenre(String genreId) async {
    await _db.collection('genres').doc(genreId).delete();
  }

  // ==================== ARTIST REGISTRATION ====================

  // User submits a request to become an artist
  static Future<void> submitArtistRequest({
    required String userId,
    required String artistName,
    String? bio,
    String? avatarUrl,
    List<String>? genres,
    String? socialLinks,
    String? sampleTrackUrl,
  }) async {
    final requestRef = _db.collection('artist_requests').doc(userId);
    await requestRef.set({
      'userId': userId,
      'artistName': artistName,
      'bio': bio ?? '',
      'avatarUrl': avatarUrl ?? '',
      'genres': genres ?? [],
      'socialLinks': socialLinks ?? '',
      'sampleTrackUrl': sampleTrackUrl ?? '',
      'status': 'pending',
      'adminNote': '',
      'createdAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
    });

    await _db.collection('users').doc(userId).update({
      'isPendingArtist': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get artist requests, optionally filtered by status
  static Future<List<Map<String, dynamic>>> getArtistRequests({String? status}) async {
    try {
      Query query = _db.collection('artist_requests');
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      final snapshot = await query.get();
      final requests = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      requests.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }
        return 0;
      });
      return requests;
    } catch (e) {
      debugPrint('Error getting artist requests: $e');
      return [];
    }
  }

  // Count pending artist requests (for admin dashboard badge)
  static Future<int> getPendingArtistRequestCount() async {
    try {
      final snapshot = await _db
          .collection('artist_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  // Approve an artist request: create artist doc + promote user
  static Future<String> approveArtistRequest(Map<String, dynamic> request) async {
    final userId = request['userId'] as String;

    final artistRef = await _db.collection('artists').add({
      'name': request['artistName'] ?? '',
      'avatarUrl': request['avatarUrl'] ?? '',
      'bio': request['bio'] ?? '',
      'genres': request['genres'] ?? [],
      'socialLinks': request['socialLinks'] ?? '',
      'monthlyListeners': 0,
      'followerCount': 0,
      'isVerified': false,
      'linkedUserId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(userId).update({
      'role': 'artist',
      'artistId': artistRef.id,
      'isPendingArtist': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('artist_requests').doc(userId).update({
      'status': 'approved',
      'artistId': artistRef.id,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    return artistRef.id;
  }

  // Reject an artist request
  static Future<void> rejectArtistRequest(String userId, String note) async {
    await _db.collection('artist_requests').doc(userId).update({
      'status': 'rejected',
      'adminNote': note,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(userId).update({
      'isPendingArtist': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get songs uploaded by a specific artist (by artistId)
  static Future<List<Song>> getSongsByArtistId(String artistId) async {
    try {
      final snapshot = await _db
          .collection('songs')
          .where('artistIds', arrayContains: artistId)
          .get();
      return snapshot.docs.map((doc) => Song.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting songs by artist: $e');
      return [];
    }
  }

  // ==================== ADMIN: STATS ====================

  // Get system stats
  static Future<Map<String, int>> getSystemStats() async {
    final songsCount = (await _db.collection('songs').get()).size;
    final artistsCount = (await _db.collection('artists').get()).size;
    final albumsCount = (await _db.collection('albums').get()).size;
    final usersCount = (await _db.collection('users').get()).size;
    final playlistsCount = (await _db.collection('playlists').get()).size;

    return {
      'songs': songsCount,
      'artists': artistsCount,
      'albums': albumsCount,
      'users': usersCount,
      'playlists': playlistsCount,
    };
  }

  // ==================== MEMBERSHIP PACKAGES ====================

  static Future<List<Map<String, dynamic>>> getSubscriptionPackages() async {
    try {
      final snapshot = await _db.collection('subscription_packages').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting packages: $e');
      return [];
    }
  }

  static Future<void> createSubscriptionPackage(Map<String, dynamic> data) async {
    await _db.collection('subscription_packages').add(data);
  }

  static Future<void> updateSubscriptionPackage(String id, Map<String, dynamic> data) async {
    await _db.collection('subscription_packages').doc(id).update(data);
  }

  static Future<void> deleteSubscriptionPackage(String id) async {
    await _db.collection('subscription_packages').doc(id).delete();
  }

  static Future<void> updateUserSubscription({
    required String userId, 
    required String userEmail,
    required String packageName, 
    required double price,
  }) async {
    final batch = _db.batch();
    
    // 1. Update user document
    final userRef = _db.collection('users').doc(userId);
    batch.update(userRef, {
      'subscriptionTier': packageName,
      'isPremium': packageName != 'Free' && packageName != 'Standard',
      'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Create subscription log
    final logRef = _db.collection('subscription_logs').doc();
    batch.set(logRef, {
      'userId': userId,
      'userEmail': userEmail,
      'packageName': packageName,
      'price': price,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  static Future<List<Map<String, dynamic>>> getSubscriptionLogs() async {
    try {
      final snapshot = await _db.collection('subscription_logs')
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('Error getting logs: $e');
      return [];
    }
  }

  static Future<double> getTotalRevenue() async {
    try {
      final snapshot = await _db.collection('subscription_logs').get();
      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['price'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    } catch (e) {
      debugPrint('Error calculating revenue: $e');
      return 0.0;
    }
  }

  static Future<String> getUserSubscriptionTier(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['subscriptionTier'] ?? 'Free';
      }
      return 'Free';
    } catch (e) {
      return 'Free';
    }
  }
}

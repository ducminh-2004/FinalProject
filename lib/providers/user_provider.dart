import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../firebase/firestore_service.dart';
import '../firebase/auth_service.dart';

enum UserRole { user, artist, admin }

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  String? _userId;
  String? _email;
  String? _displayName;
  String? _photoUrl;
  UserRole _role = UserRole.user;
  String _subscriptionTier = 'Free';
  List<String> _likedSongIds = [];
  List<String> _likedAlbumIds = [];
  List<String> _followedArtistIds = [];
  bool _isLoading = false;
  bool _isPendingArtist = false;
  String? _artistId;

  StreamSubscription? _likedSongsSub;
  StreamSubscription? _likedAlbumsSub;
  StreamSubscription? _followedArtistsSub;

  String? get userId => _userId;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get photoUrl => _photoUrl;
  UserRole get role => _role;
  String get subscriptionTier => _subscriptionTier;
  List<String> get likedSongIds => _likedSongIds;
  List<String> get likedAlbumIds => _likedAlbumIds;
  List<String> get followedArtistIds => _followedArtistIds;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _userId != null;
  bool get isAdmin => _role == UserRole.admin;
  bool get isArtist => _role == UserRole.artist;
  bool get isPendingArtist => _isPendingArtist;
  String? get artistId => _artistId;

  dynamic get currentUser => _authService.currentUser;

  UserProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        _userId = user.uid;
        _email = user.email;
        _displayName = user.displayName;
        _photoUrl = user.photoURL;
        await _loadUserRole();
        await _loadSubscriptionTier();
        _setupFirestoreListeners();
      } else {
        signOut();
      }
    });
  }

  void _setupFirestoreListeners() {
    if (_userId == null) return;

    _cancelFirestoreListeners();

    _likedSongsSub = FirebaseFirestore.instance
        .collection('liked_songs')
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .listen((snap) {
      _likedSongIds = snap.docs.map((doc) => doc.data()['songId'] as String).toList();
      notifyListeners();
    });

    _likedAlbumsSub = FirebaseFirestore.instance
        .collection('liked_albums')
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .listen((snap) {
      _likedAlbumIds = snap.docs.map((doc) => doc.data()['albumId'] as String).toList();
      notifyListeners();
    });

    _followedArtistsSub = FirebaseFirestore.instance
        .collection('followed_artists')
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .listen((snap) {
      _followedArtistIds = snap.docs.map((doc) => doc.data()['artistId'] as String).toList();
      notifyListeners();
    });
  }

  void _cancelFirestoreListeners() {
    _likedSongsSub?.cancel();
    _likedAlbumsSub?.cancel();
    _followedArtistsSub?.cancel();
  }

  Future<void> _loadUserRole() async {
    if (_userId == null) return;

    try {
      final status = await FirestoreService.getUserRoleStatus(_userId!);
      final roleStr = status['role'] as String? ?? 'user';
      if (roleStr == 'admin' || status['isAdmin'] == true) {
        _role = UserRole.admin;
      } else if (roleStr == 'artist') {
        _role = UserRole.artist;
      } else {
        _role = UserRole.user;
      }
      _isPendingArtist = status['isPendingArtist'] as bool? ?? false;
      _artistId = status['artistId'] as String?;
    } catch (e) {
      debugPrint('Error loading user role: $e');
      _role = UserRole.user;
      _isPendingArtist = false;
      _artistId = null;
    }

    notifyListeners();
  }

  Future<void> reloadRole() async {
    await _loadUserRole();
  }

  Future<void> _loadSubscriptionTier() async {
    if (_userId == null) return;
    try {
      _subscriptionTier = await FirestoreService.getUserSubscriptionTier(_userId!);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading subscription tier: $e');
    }
  }

  Future<void> upgradeSubscription(String packageName, double price) async {
    if (_userId == null) return;
    try {
      await FirestoreService.updateUserSubscription(
        userId: _userId!,
        userEmail: _email ?? 'Unknown',
        packageName: packageName,
        price: price,
      );
      _subscriptionTier = packageName;
      notifyListeners();
    } catch (e) {
      debugPrint('Error upgrading subscription: $e');
      rethrow;
    }
  }

  bool isSongLiked(String songId) {
    return _likedSongIds.contains(songId);
  }

  bool isAlbumLiked(String albumId) {
    return _likedAlbumIds.contains(albumId);
  }

  bool isArtistFollowed(String artistId) {
    return _followedArtistIds.contains(artistId);
  }

  Future<void> toggleLikeSong(String songId) async {
    if (_userId == null) {
      debugPrint('User not logged in');
      return;
    }

    try {
      await FirestoreService.toggleLikeSong(_userId!, songId);
      // Local list is updated by Firestore snapshot listener
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  // Alias for backward compatibility
  Future<void> toggleLike(String songId) => toggleLikeSong(songId);

  Future<void> toggleLikeAlbum(String albumId) async {
    if (_userId == null) return;

    try {
      await FirestoreService.toggleLikeAlbum(_userId!, albumId);
      // Local list is updated by Firestore snapshot listener
    } catch (e) {
      debugPrint('Error toggling album like: $e');
    }
  }

  Future<void> toggleFollowArtist(String artistId) async {
    if (_userId == null) {
      debugPrint('User not logged in');
      return;
    }

    try {
      await FirestoreService.toggleFollowArtist(_userId!, artistId);
      // Local list is updated by Firestore snapshot listener
    } catch (e) {
      debugPrint('Error toggling follow artist: $e');
    }
  }

  Future<List<Song>> getLikedSongs() async {
    if (_userId == null) return [];

    final songs = <Song>[];
    for (final songId in _likedSongIds) {
      final song = await FirestoreService.getSongById(songId);
      if (song != null) songs.add(song);
    }
    return songs;
  }

  Future<List<Artist>> getFollowedArtists() async {
    if (_userId == null) return [];
    
    final artists = <Artist>[];
    for (final artistId in _followedArtistIds) {
      final artist = await FirestoreService.getArtistById(artistId);
      if (artist != null) artists.add(artist);
    }
    return artists;
  }

  Future<List<Album>> getLikedAlbums() async {
    if (_userId == null) return [];

    final albums = <Album>[];
    for (final albumId in _likedAlbumIds) {
      final album = await FirestoreService.getAlbumById(albumId);
      if (album != null) albums.add(album);
    }
    return albums;
  }

  Future<void> refreshUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      _displayName = user.displayName;
      _photoUrl = user.photoURL;
      notifyListeners();
    }
  }

  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    try {
      await _authService.updateProfile(
        displayName: displayName,
        photoURL: photoUrl,
      );
      if (displayName != null) _displayName = displayName;
      if (photoUrl != null) _photoUrl = photoUrl;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  void signOut() {
    _cancelFirestoreListeners();
    _userId = null;
    _email = null;
    _displayName = null;
    _photoUrl = null;
    _role = UserRole.user;
    _likedSongIds = [];
    _likedAlbumIds = [];
    _followedArtistIds = [];
    _isPendingArtist = false;
    _artistId = null;
    _authService.signOut();
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelFirestoreListeners();
    super.dispose();
  }
}

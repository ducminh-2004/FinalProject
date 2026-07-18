import 'package:flutter/material.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../firebase/firestore_service.dart';
import '../firebase/auth_service.dart';

enum UserRole { user, admin }

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  String? _userId;
  String? _email;
  String? _displayName;
  String? _photoUrl;
  UserRole _role = UserRole.user;
  String _subscriptionTier = 'Free';
  List<String> _likedSongIds = [];
  List<String> _followedArtistIds = [];
  bool _isLoading = false;

  String? get userId => _userId;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get photoUrl => _photoUrl;
  UserRole get role => _role;
  String get subscriptionTier => _subscriptionTier;
  List<String> get likedSongIds => _likedSongIds;
  List<String> get followedArtistIds => _followedArtistIds;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _userId != null;
  bool get isAdmin => _role == UserRole.admin;

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
        _loadLikedSongs();
        _loadFollowedArtists();
      } else {
        _userId = null;
        _email = null;
        _displayName = null;
        _photoUrl = null;
        _role = UserRole.user;
        _subscriptionTier = 'Free';
        _likedSongIds = [];
        _followedArtistIds = [];
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserRole() async {
    if (_userId == null) return;
    
    try {
      final isAdmin = await FirestoreService.checkUserIsAdmin(_userId!);
      _role = isAdmin ? UserRole.admin : UserRole.user;
    } catch (e) {
      debugPrint('Error loading user role: $e');
      _role = UserRole.user;
    }
    
    notifyListeners();
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

  Future<void> upgradeSubscription(String packageName) async {
    if (_userId == null) return;
    try {
      await FirestoreService.updateUserSubscription(_userId!, packageName);
      _subscriptionTier = packageName;
      notifyListeners();
    } catch (e) {
      debugPrint('Error upgrading subscription: $e');
      rethrow;
    }
  }

  Future<void> _loadLikedSongs() async {
    if (_userId == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      _likedSongIds = await FirestoreService.getLikedSongIds(_userId!);
    } catch (e) {
      debugPrint('Error loading liked songs: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadFollowedArtists() async {
    if (_userId == null) return;
    
    try {
      _followedArtistIds = await FirestoreService.getFollowedArtistIds(_userId!);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading followed artists: $e');
    }
  }

  bool isSongLiked(String songId) {
    return _likedSongIds.contains(songId);
  }

  bool isArtistFollowed(String artistId) {
    return _followedArtistIds.contains(artistId);
  }

  Future<void> toggleLike(String songId) async {
    if (_userId == null) {
      debugPrint('User not logged in');
      return;
    }

    try {
      await FirestoreService.toggleLikeSong(_userId!, songId);
      
      if (_likedSongIds.contains(songId)) {
        _likedSongIds.remove(songId);
      } else {
        _likedSongIds.add(songId);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> toggleFollowArtist(String artistId) async {
    if (_userId == null) {
      debugPrint('User not logged in');
      return;
    }

    try {
      await FirestoreService.toggleFollowArtist(_userId!, artistId);
      
      if (_followedArtistIds.contains(artistId)) {
        _followedArtistIds.remove(artistId);
      } else {
        _followedArtistIds.add(artistId);
      }
      
      notifyListeners();
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

    debugPrint('UserProvider: Getting followed artists for $_userId, IDs: $_followedArtistIds');
    
    final artists = <Artist>[];
    for (final artistId in _followedArtistIds) {
      debugPrint('UserProvider: Loading artist $artistId');
      
      final artist = await FirestoreService.getArtistById(artistId);
      
      if (artist != null) {
        debugPrint('UserProvider: Found in Firestore: ${artist.name}');
        artists.add(artist);
      }
    }
    
    debugPrint('UserProvider: Total artists: ${artists.length}');
    return artists;
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
    _userId = null;
    _email = null;
    _displayName = null;
    _photoUrl = null;
    _role = UserRole.user;
    _likedSongIds = [];
    _followedArtistIds = [];
    _authService.signOut();
    notifyListeners();
  }
}

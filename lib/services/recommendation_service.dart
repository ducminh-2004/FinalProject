import '../models/view_model.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../firebase/firestore_service.dart';
import 'view_service.dart';

class RecommendationService {
  // Get recommended songs based on user's listening history
  static Future<List<Song>> getRecommendedSongs({
    String? userId,
    int limit = 10,
  }) async {
    try {
      // Get user's recently viewed songs
      final history = userId != null
          ? await ViewService.getUserHistory(userId, limit: 20)
          : <ViewRecord>[];

      // Get viewed song IDs
      final viewedSongIds = history
          .where((v) => v.targetType == ViewTargetType.song)
          .map((v) => v.targetId)
          .toSet()
          .toList();

      // Get similar songs from same artists
      final similarSongs = <Song>[];
      for (final songId in viewedSongIds.take(5)) {
        final artist = await _getArtistOfSong(songId);
        if (artist?.songIds != null) {
          for (final id in artist!.songIds!) {
            if (!viewedSongIds.contains(id)) {
              final song = await FirestoreService.getSongById(id);
              if (song != null) similarSongs.add(song);
            }
          }
        }
      }

      // If not enough, get trending songs
      if (similarSongs.length < limit) {
        final trending = await ViewService.getTopSongs(limit: limit);
        for (final data in trending) {
          final song = await FirestoreService.getSongById(data['id']);
          if (song != null && !similarSongs.any((s) => s.id == song.id)) {
            similarSongs.add(song);
          }
        }
      }

      return similarSongs.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // Get recommended artists based on viewed artists
  static Future<List<Artist>> getRecommendedArtists({
    String? userId,
    int limit = 10,
  }) async {
    try {
      final history = userId != null
          ? await ViewService.getUserHistory(userId, limit: 20)
          : <ViewRecord>[];

      final viewedArtistIds = history
          .where((v) => v.targetType == ViewTargetType.artist)
          .map((v) => v.targetId)
          .toSet()
          .toList();

      // Get artists with similar genres or frequent views
      final trending = await ViewService.getTopArtists(limit: limit);
      final artists = <Artist>[];

      for (final data in trending) {
        final artist = await FirestoreService.getArtistById(data['id']);
        if (artist != null && !viewedArtistIds.contains(artist.id)) {
          artists.add(artist);
        }
      }

      return artists.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // Get songs trending this week
  static Future<List<Song>> getTrendingSongs({int limit = 10}) async {
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final trending = await ViewService.getTopSongs(
        limit: limit,
        since: weekAgo,
      );

      final songs = <Song>[];
      for (final data in trending) {
        final song = await FirestoreService.getSongById(data['id']);
        if (song != null) songs.add(song);
      }

      return songs;
    } catch (e) {
      return [];
    }
  }

  // Get top artists this week
  static Future<List<Artist>> getTopArtistsThisWeek({int limit = 10}) async {
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final trending = await ViewService.getTopArtists(
        limit: limit,
        since: weekAgo,
      );

      final artists = <Artist>[];
      for (final data in trending) {
        final artist = await FirestoreService.getArtistById(data['id']);
        if (artist != null) artists.add(artist);
      }

      return artists;
    } catch (e) {
      return [];
    }
  }

  // Helper: Get artist of a song
  static Future<Artist?> _getArtistOfSong(String songId) async {
    try {
      final song = await FirestoreService.getSongById(songId);
      if (song != null && song.artistIds.isNotEmpty) {
        return await FirestoreService.getArtistById(song.artistIds.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get listening stats for user
  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final history = await ViewService.getUserHistory(userId, limit: 100);

      final songViews = history.where((v) => v.targetType == ViewTargetType.song).length;
      final albumViews = history.where((v) => v.targetType == ViewTargetType.album).length;
      final artistViews = history.where((v) => v.targetType == ViewTargetType.artist).length;
      final totalListenTime = history.fold<int>(
        0,
        (sum, v) => sum + v.durationSeconds,
      );

      return {
        'totalSongs': songViews,
        'totalAlbums': albumViews,
        'totalArtists': artistViews,
        'totalListenTimeMinutes': (totalListenTime / 60).round(),
        'uniqueSongs': history
            .where((v) => v.targetType == ViewTargetType.song)
            .map((v) => v.targetId)
            .toSet()
            .length,
      };
    } catch (e) {
      return {};
    }
  }
}

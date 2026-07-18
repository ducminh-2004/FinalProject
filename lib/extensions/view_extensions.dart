import '../models/view_model.dart';
import '../services/view_service.dart';

extension Viewable on String {
  /// Track a view for a song
  Future<void> trackSongView({String? userId, int durationSeconds = 0}) async {
    await ViewService.trackView(
      targetType: ViewTargetType.song,
      targetId: this,
      userId: userId,
      durationSeconds: durationSeconds,
    );
  }

  /// Track a view for an album
  Future<void> trackAlbumView({String? userId, int durationSeconds = 0}) async {
    await ViewService.trackView(
      targetType: ViewTargetType.album,
      targetId: this,
      userId: userId,
      durationSeconds: durationSeconds,
    );
  }

  /// Track a view for an artist
  Future<void> trackArtistView({String? userId}) async {
    await ViewService.trackView(
      targetType: ViewTargetType.artist,
      targetId: this,
      userId: userId,
    );
  }
}

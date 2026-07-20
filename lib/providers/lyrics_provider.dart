import 'package:flutter/material.dart';
import '../models/lyric_line.dart';
import '../services/lyrics_service.dart';

class LyricsProvider extends ChangeNotifier {
  List<LyricLine> _lyrics = [];
  bool _isLoading = false;
  String? _currentSongId;
  bool _isVisible = false;

  List<LyricLine> get lyrics => _lyrics;
  bool get isLoading => _isLoading;
  bool get isVisible => _isVisible;
  bool get hasLyrics => _lyrics.isNotEmpty;
  String? get currentSongId => _currentSongId;

  /// Binary-search to find the last line whose timeMs <= positionMs.
  int getCurrentIndex(int positionMs) {
    if (_lyrics.isEmpty) return -1;
    int lo = 0, hi = _lyrics.length - 1, result = -1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (_lyrics[mid].timeMs <= positionMs) {
        result = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return result;
  }

  Future<void> loadLyrics(String songId) async {
    if (_currentSongId == songId) return;
    _currentSongId = songId;
    _lyrics = [];
    _isLoading = true;
    notifyListeners();

    _lyrics = await LyricsService.fetchLyrics(songId);
    _isLoading = false;
    notifyListeners();
  }

  void clearLyrics() {
    _lyrics = [];
    _currentSongId = null;
    _isVisible = false;
    notifyListeners();
  }

  void toggleVisibility() {
    _isVisible = !_isVisible;
    notifyListeners();
  }

  void setVisible(bool visible) {
    if (_isVisible == visible) return;
    _isVisible = visible;
    notifyListeners();
  }

  void reloadLyrics(String songId) {
    LyricsService.invalidateCache(songId);
    _currentSongId = null;
    loadLyrics(songId);
  }
}

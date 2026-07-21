import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/song.dart';
import '../models/view_model.dart';
import '../extensions/view_extensions.dart';
import '../firebase/firestore_service.dart';
import '../services/view_service.dart';

enum AppPlayerState { stopped, playing, paused, completed }

enum RepeatMode { none, all, one }

class AudioProvider extends ChangeNotifier {
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();

  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isShuffle = false;
  RepeatMode _repeatMode = RepeatMode.none;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  AppPlayerState _playerState = AppPlayerState.stopped;

  Timer? _positionTimer;
  bool _isRadioMode = false;
  Timer? _sleepTimer;
  Timer? _sleepCountdown;
  Duration? _sleepRemaining;

  // Listen-time tracking
  DateTime? _songStartTime;
  bool _completionHandled = false;
  String? _currentViewDocId;

  // True when playback reached the end with nothing queued to play next
  bool _songEnded = false;

  // Getters
  Song? get currentSong => _currentSong;
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isShuffle => _isShuffle;
  RepeatMode get repeatMode => _repeatMode;
  bool get isRepeat => _repeatMode != RepeatMode.none;
  Duration get position => _position;
  Duration get duration => _duration;
  AppPlayerState get playerState => _playerState;
  bool get hasSong => _currentSong != null;
  bool get songEnded => _songEnded;
  bool get hasSleepTimer => _sleepTimer != null;
  Duration? get sleepRemaining => _sleepRemaining;
  bool get isRadioMode => _isRadioMode;

  AudioProvider() {
    _initListeners();
  }

  void _initListeners() {
    _audioPlayer.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      switch (state) {
        case ap.PlayerState.playing:
          _isPlaying = true;
          _playerState = AppPlayerState.playing;
          _completionHandled = false;
          _songEnded = false;
          _startPositionTimer();
          break;
        case ap.PlayerState.paused:
          _isPlaying = false;
          _playerState = AppPlayerState.paused;
          _stopPositionTimer();
          break;
        case ap.PlayerState.stopped:
          _isPlaying = false;
          _playerState = AppPlayerState.stopped;
          _stopPositionTimer();
          break;
        case ap.PlayerState.completed:
          _isPlaying = false;
          _playerState = AppPlayerState.completed;
          _stopPositionTimer();
          _handleCompletion();
          break;
        default:
          break;
      }
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _handleCompletion();
    });
  }

  void _handleCompletion() {
    if (_completionHandled) return;
    _completionHandled = true;
    _recordListenTime();
    _onSongComplete();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!_isPlaying) return;
      final pos = await _audioPlayer.getCurrentPosition();
      if (pos != null && (pos - _position).abs() > const Duration(milliseconds: 100)) {
        _position = pos;
        notifyListeners();
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  // Record actual listening duration to Firestore
  void _recordListenTime() {
    if (_songStartTime == null || _currentSong == null) return;
    final elapsed = DateTime.now().difference(_songStartTime!).inSeconds;
    _songStartTime = null;
    final viewDocId = _currentViewDocId;
    _currentViewDocId = null;
    if (elapsed < 3) return;
    final songId = _currentSong!.id;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    // Global aggregate listen time
    ViewService.updateListenTime(songId: songId, durationSeconds: elapsed, userId: userId);
    // Per-user view record duration (drives monthly listen-time stat)
    if (viewDocId != null) {
      ViewService.updateViewRecordDuration(viewDocId: viewDocId, durationSeconds: elapsed);
    }
  }

  bool isRemoteControlled = false;

  void _onSongComplete() {
    if (isRemoteControlled) return;

    if (_repeatMode == RepeatMode.one && _currentSong != null) {
      playSong(_currentSong!, restart: true);
      return;
    }

    if (_currentIndex >= _playlist.length - 1) {
      if (_isRadioMode && _currentSong != null) {
        _fetchRadioSuggestions(_currentSong!);
      } else if (_repeatMode == RepeatMode.all && _playlist.isNotEmpty) {
        _currentIndex = 0;
        playSong(_playlist[0]);
      } else {
        _endPlaylist();
      }
    } else {
      playNext();
    }
  }

  // End of playlist — keep current song visible so user can replay
  Future<void> _endPlaylist() async {
    _isPlaying = false;
    _position = Duration.zero;
    _playerState = AppPlayerState.stopped;
    _songEnded = true;
    await _audioPlayer.stop();
    notifyListeners();
  }

  Future<void> _fetchRadioSuggestions(Song baseSong) async {
    try {
      List<Song> suggestions = [];
      if (baseSong.genres.isNotEmpty) {
        suggestions = await FirestoreService.getSongsByGenreName(baseSong.genres.first, limit: 10);
      }
      if (suggestions.isEmpty) {
        suggestions = await FirestoreService.getSongs();
      }
      final existingIds = _playlist.map((s) => s.id).toSet();
      final fresh = suggestions.where((s) => !existingIds.contains(s.id)).toList();
      if (fresh.isNotEmpty) {
        _playlist.addAll(fresh);
        notifyListeners();
        await playNext();
      }
    } catch (_) {}
  }

  void toggleRadioMode() {
    _isRadioMode = !_isRadioMode;
    notifyListeners();
  }

  Future<void> playSong(Song song, {bool restart = false, String? userId}) async {
    if (song.audioUrl == null || song.audioUrl!.isEmpty) return;

    if (_currentSong?.id == song.id && _isPlaying && !restart) {
      return;
    }

    // Save listen time for the song being replaced
    if (_currentSong?.id != song.id) {
      _recordListenTime();
    }

    // Stop current playback to clear buffers and positions
    await _audioPlayer.stop();

    _currentSong = song;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = true;
    _completionHandled = false;
    _songEnded = false;
    _songStartTime = DateTime.now();
    notifyListeners();

    final effectiveUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
    _currentViewDocId = null;
    song.id.trackSongView(userId: effectiveUserId, durationSeconds: 0).then((docId) {
      _currentViewDocId = docId;
    });

    // Cập nhật lượt nghe cho Album nếu bài hát thuộc album (tương lai có thể mở rộng)
    // Hiện tại extension trackSongView đã tự xử lý logic liên quan đến bài hát.

    if (!restart) {
      final existingIndex = _playlist.indexWhere((s) => s.id == song.id);
      if (existingIndex >= 0) {
        _currentIndex = existingIndex;
      }
    }

    await _audioPlayer.setSourceUrl(song.audioUrl!);
    await _audioPlayer.resume();
  }

  Future<void> playPlaylist(List<Song> songs, {int startIndex = 0, String? userId}) async {
    if (songs.isEmpty) return;

    _playlist = _isShuffle ? (List.from(songs)..shuffle()) : List.from(songs);
    _currentIndex = startIndex;

    if (_isShuffle && startIndex > 0) {
      final selectedSong = _playlist.removeAt(startIndex);
      _playlist.insert(0, selectedSong);
      _currentIndex = 0;
    }

    await playSong(_playlist[_currentIndex], userId: userId);
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      _isPlaying = false;
      notifyListeners();
      await _audioPlayer.pause();
    } else {
      // If song ended naturally, restart it
      if (_currentSong != null &&
          (_songEnded ||
           _playerState == AppPlayerState.completed ||
           _playerState == AppPlayerState.stopped)) {
        await playSong(_currentSong!, restart: true);
      } else {
        _isPlaying = true;
        notifyListeners();
        await _audioPlayer.resume();
      }
    }
  }

  Future<void> play() async {
    _isPlaying = true;
    notifyListeners();
    await _audioPlayer.resume();
  }

  Future<void> pause() async {
    _isPlaying = false;
    notifyListeners();
    await _audioPlayer.pause();
  }

  // Full stop — clears current song (explicit user action)
  Future<void> stop() async {
    _recordListenTime();
    _isPlaying = false;
    await _audioPlayer.stop();
    _currentSong = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    _currentIndex++;
    if (_currentIndex >= _playlist.length) {
      if (_repeatMode == RepeatMode.all) {
        _currentIndex = 0;
      } else {
        _currentIndex = _playlist.length - 1;
        await _endPlaylist();
        return;
      }
    }

    await playSong(_playlist[_currentIndex]);
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    _currentIndex--;
    if (_currentIndex < 0) {
      _currentIndex = 0;
    }

    await playSong(_playlist[_currentIndex]);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;

    if (_isShuffle && _playlist.isNotEmpty && _currentSong != null) {
      _playlist.remove(_currentSong);
      _playlist.shuffle();
      _playlist.insert(0, _currentSong!);
      _currentIndex = 0;
    }

    notifyListeners();
  }

  // Cycles: none → all → one → none
  void toggleRepeat() {
    switch (_repeatMode) {
      case RepeatMode.none:
        _repeatMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.none;
        break;
    }
    notifyListeners();
  }

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    _sleepRemaining = duration;
    notifyListeners();

    _sleepTimer = Timer(duration, () {
      pause();
      _sleepTimer = null;
      _sleepRemaining = null;
      _sleepCountdown?.cancel();
      _sleepCountdown = null;
      notifyListeners();
    });

    _sleepCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sleepRemaining != null && _sleepRemaining!.inSeconds > 0) {
        _sleepRemaining = _sleepRemaining! - const Duration(seconds: 1);
        notifyListeners();
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    _sleepTimer = null;
    _sleepCountdown = null;
    _sleepRemaining = null;
    notifyListeners();
  }

  void setPlaylist(List<Song> songs) {
    _playlist = List.from(songs);
    notifyListeners();
  }

  Duration get playlistDuration {
    return _playlist.fold(
      Duration.zero,
      (total, song) => total + Duration(milliseconds: song.durationMs ?? 0),
    );
  }

  @override
  void dispose() {
    _recordListenTime();
    _stopPositionTimer();
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

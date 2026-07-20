import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/song.dart';
import '../extensions/view_extensions.dart';

enum PlayerState { stopped, playing, paused, completed }

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Current playback state
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isShuffle = false;
  bool _isRepeat = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;

  // Getters
  Song? get currentSong => _currentSong;
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;
  Duration get position => _position;
  Duration get duration => _duration;
  PlayerState get playerState => _playerState;
  bool get hasSong => _currentSong != null;

  AudioProvider() {
    _initListeners();
  }

  void _initListeners() {
    // Duration listener
    _audioPlayer.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });

    // Position listener
    _audioPlayer.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });

    // Player state listener
    _audioPlayer.onPlayerStateChanged.listen((state) {
      switch (state) {
        case PlayerState.playing:
          _isPlaying = true;
          _playerState = PlayerState.playing;
          break;
        case PlayerState.paused:
          _isPlaying = false;
          _playerState = PlayerState.paused;
          break;
        case PlayerState.stopped:
          _isPlaying = false;
          _playerState = PlayerState.stopped;
          break;
        case PlayerState.completed:
          _isPlaying = false;
          _playerState = PlayerState.completed;
          _onSongComplete();
          break;
        default:
          break;
      }
      notifyListeners();
    });

    // Completion listener
    _audioPlayer.onPlayerComplete.listen((_) {
      _onSongComplete();
    });
  }

  void _onSongComplete() {
    if (_isRepeat) {
      playSong(_currentSong!, restart: true);
    } else {
      playNext();
    }
  }

  // Play a single song
  Future<void> playSong(Song song, {bool restart = false, String? userId}) async {
    if (song.audioUrl == null || song.audioUrl!.isEmpty) return;

    // Nếu là bài hiện tại và đang phát, không restart
    if (_currentSong?.id == song.id && _isPlaying && !restart) {
      return;
    }

    _currentSong = song;
    _position = Duration.zero;
    _isPlaying = true; // Set trước để UI update ngay
    notifyListeners();

    // Track song view
    // Always associate the history entry with the signed-in user. Most callers
    // do not have to (and previously did not) pass a userId explicitly.
    final effectiveUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
    song.id.trackSongView(
      userId: effectiveUserId,
      durationSeconds: 0,
    );

    if (!restart) {
      // Check if song is already in playlist
      final existingIndex = _playlist.indexWhere((s) => s.id == song.id);
      if (existingIndex >= 0) {
        _currentIndex = existingIndex;
      }
    }

    await _audioPlayer.setSourceUrl(song.audioUrl!);
    await _audioPlayer.resume();
  }

  // Play a playlist from specific index
  Future<void> playPlaylist(List<Song> songs, {int startIndex = 0, String? userId}) async {
    if (songs.isEmpty) return;

    _playlist = _isShuffle ? (List.from(songs)..shuffle()) : List.from(songs);
    _currentIndex = startIndex;
    
    if (_isShuffle && startIndex > 0) {
      // Move the selected song to first position in shuffled list
      final selectedSong = _playlist.removeAt(startIndex);
      _playlist.insert(0, selectedSong);
      _currentIndex = 0;
    }

    await playSong(_playlist[_currentIndex], userId: userId);
  }

  // Resume/Pause
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      _isPlaying = false;
      notifyListeners();
      await _audioPlayer.pause();
    } else {
      _isPlaying = true;
      notifyListeners();
      await _audioPlayer.resume();
    }
  }

  // Play
  Future<void> play() async {
    _isPlaying = true;
    notifyListeners();
    await _audioPlayer.resume();
  }

  // Pause
  Future<void> pause() async {
    _isPlaying = false;
    notifyListeners();
    await _audioPlayer.pause();
  }

  // Stop
  Future<void> stop() async {
    _isPlaying = false;
    await _audioPlayer.stop();
    _currentSong = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  // Seek to position
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  // Play next song
  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    _currentIndex++;
    if (_currentIndex >= _playlist.length) {
      if (_isRepeat) {
        _currentIndex = 0;
      } else {
        _currentIndex = _playlist.length - 1;
        await stop();
        return;
      }
    }

    await playSong(_playlist[_currentIndex]);
  }

  // Play previous song
  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    // If position > 3 seconds, restart current song
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

  // Toggle shuffle
  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    
    if (_isShuffle && _playlist.isNotEmpty && _currentSong != null) {
      // Shuffle but keep current song at first position
      _playlist.remove(_currentSong);
      _playlist.shuffle();
      _playlist.insert(0, _currentSong!);
      _currentIndex = 0;
    }
    
    notifyListeners();
  }

  // Toggle repeat
  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    notifyListeners();
  }

  // Set playlist
  void setPlaylist(List<Song> songs) {
    _playlist = List.from(songs);
    notifyListeners();
  }

  // Get total duration of playlist
  Duration get playlistDuration {
    return _playlist.fold(
      Duration.zero,
      (total, song) => total + Duration(milliseconds: song.durationMs ?? 0),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

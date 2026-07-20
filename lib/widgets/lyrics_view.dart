import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../providers/lyrics_provider.dart';

class LyricsView extends StatefulWidget {
  const LyricsView({super.key});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastIndex = -2;

  // Approximate height per lyric line (padding + text).
  static const double _itemEstimatedHeight = 76.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    if (index < 0) return;

    final viewportHeight = _scrollController.position.viewportDimension;
    final target = index * _itemEstimatedHeight
        - viewportHeight / 2
        + _itemEstimatedHeight / 2;
    final clamped = target.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AudioProvider, LyricsProvider>(
      builder: (context, audio, lyricsProvider, _) {
        final positionMs = audio.position.inMilliseconds;
        final currentIndex = lyricsProvider.getCurrentIndex(positionMs);

        if (currentIndex != _lastIndex) {
          _lastIndex = currentIndex;
          if (currentIndex >= 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _scrollToIndex(currentIndex);
            });
          }
        }

        if (lyricsProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2,
            ),
          );
        }

        if (!lyricsProvider.hasLyrics) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_off_rounded, color: Colors.white24, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Chưa có lời bài hát',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final lyrics = lyricsProvider.lyrics;

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 28),
          itemCount: lyrics.length,
          itemBuilder: (context, index) {
            final line = lyrics[index];
            final isCurrent = index == currentIndex;
            final isPast = index < currentIndex;

            return GestureDetector(
              onTap: () => audio.seek(Duration(milliseconds: line.timeMs)),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  style: TextStyle(
                    color: isCurrent
                        ? Colors.white
                        : isPast
                            ? Colors.white30
                            : Colors.white54,
                    fontSize: isCurrent ? 26 : 20,
                    fontWeight:
                        isCurrent ? FontWeight.w800 : FontWeight.w500,
                    height: 1.3,
                  ),
                  child: Text(line.text),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

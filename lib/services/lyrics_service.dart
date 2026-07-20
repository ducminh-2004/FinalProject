import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/lyric_line.dart';

class LyricsService {
  static final _db = FirebaseFirestore.instance;
  static final Map<String, List<LyricLine>> _cache = {};

  static Future<List<LyricLine>> fetchLyrics(String songId) async {
    if (_cache.containsKey(songId)) return _cache[songId]!;

    try {
      final doc = await _db
          .collection('songs')
          .doc(songId)
          .collection('lyrics')
          .doc('lines')
          .get();
      if (!doc.exists) return [];

      final data = doc.data();
      if (data == null || data['lines'] == null) return [];

      final lines = (data['lines'] as List)
          .map((e) => LyricLine.fromMap(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.timeMs.compareTo(b.timeMs));

      _cache[songId] = lines;
      return lines;
    } catch (e) {
      debugPrint('Error fetching lyrics: $e');
      return [];
    }
  }

  static Future<void> uploadLyrics(
      String songId, List<LyricLine> lines) async {
    final sorted = [...lines]..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    await _db
        .collection('songs')
        .doc(songId)
        .collection('lyrics')
        .doc('lines')
        .set({
      'lines': sorted.map((l) => l.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _cache[songId] = sorted;
  }

  static Future<void> deleteLyrics(String songId) async {
    await _db
        .collection('songs')
        .doc(songId)
        .collection('lyrics')
        .doc('lines')
        .delete();
    _cache.remove(songId);
  }

  static void invalidateCache(String songId) => _cache.remove(songId);

  /// Parse LRC format: [mm:ss.xx] lyric text
  static List<LyricLine> parseLrc(String lrcText) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final raw in lrcText.split('\n')) {
      final match = regex.firstMatch(raw.trim());
      if (match == null) continue;

      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final centStr = match.group(3)!;
      final ms = centStr.length == 2
          ? int.parse(centStr) * 10
          : int.parse(centStr);
      final text = match.group(4)!.trim();
      if (text.isEmpty) continue;

      lines.add(LyricLine(
        timeMs: (minutes * 60 + seconds) * 1000 + ms,
        text: text,
      ));
    }

    return lines..sort((a, b) => a.timeMs.compareTo(b.timeMs));
  }

  /// Convert list of LyricLine back to LRC text
  static String toLrc(List<LyricLine> lines) {
    return lines.map((l) {
      final total = l.timeMs;
      final m = total ~/ 60000;
      final s = (total % 60000) ~/ 1000;
      final ms = total % 1000;
      return '[${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${(ms ~/ 10).toString().padLeft(2, '0')}]${l.text}';
    }).join('\n');
  }
}

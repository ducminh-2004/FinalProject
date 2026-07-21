import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/view_model.dart';
import '../firebase/firestore_service.dart';

class ViewService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<String?> trackView({
    required ViewTargetType targetType,
    required String targetId,
    String? userId,
    int durationSeconds = 0,
  }) async {
    try {
      final record = ViewRecord.create(
        targetType: targetType,
        targetId: targetId,
        userId: userId,
        durationSeconds: durationSeconds,
      );
      await _db.collection('views').add(record.toFirestore());
      await _updateStats(targetType, targetId, userId, durationSeconds);
      if (targetType == ViewTargetType.song) {
        await _updateDailyTargetStats(targetId);
        await _incrementArtistStreamCount(targetId, userId, durationSeconds);
      }
      return "ok";
    } catch (e) { return null; }
  }

  static Future<void> _updateDailyTargetStats(String songId) async {
    final today = _formatDate(DateTime.now());
    await _db.collection('daily_song_stats').doc('${songId}_$today').set({
      'songId': songId, 'date': today, 'views': FieldValue.increment(1), 'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _incrementArtistStreamCount(String songId, String? userId, int durationSeconds) async {
    try {
      final songDoc = await _db.collection('songs').doc(songId).get();
      if (!songDoc.exists) return;
      final data = songDoc.data()!;
      List<String> ids = (data['artistIds'] is List) ? (data['artistIds'] as List).cast<String>() : 
                        (data['artistId'] is String ? [data['artistId'] as String] : []);
      for (final artistId in ids) {
        if (artistId.isNotEmpty) await _updateStats(ViewTargetType.artist, artistId, userId, durationSeconds);
      }
    } catch (e) {}
  }

  static Future<void> _updateStats(ViewTargetType targetType, String targetId, String? userId, int durationSeconds) async {
    final ref = _db.collection('view_stats').doc('${targetType.name}_$targetId');
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (doc.exists) tx.update(ref, {'totalViews': FieldValue.increment(1), 'totalListenTime': FieldValue.increment(durationSeconds), 'lastViewedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
      else tx.set(ref, {'targetType': targetType.name, 'targetId': targetId, 'totalViews': 1, 'totalListenTime': durationSeconds, 'lastViewedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    });
  }

  static Future<void> updateListenTime({required String songId, required int durationSeconds, String? userId}) async {
    if (durationSeconds <= 0) return;
    try { await _db.collection('view_stats').doc('song_$songId').set({'totalListenTime': FieldValue.increment(durationSeconds), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)); } catch (e) {}
  }

  static Future<void> updateViewRecordDuration({required String viewDocId, required int durationSeconds}) async {
    if (durationSeconds <= 0) return;
    try { await _db.collection('views').doc(viewDocId).update({'durationSeconds': durationSeconds}); } catch (e) {}
  }

  // --- TRENDING REAL-TIME STREAM (SỬ DỤNG VIEW_STATS TRỰC TIẾP) ---

  static Stream<List<Map<String, dynamic>>> getTrendingSongsStream({int limit = 50}) {
    debugPrint('[TRENDING] Fetching Trending for last 3 days...');
    return _db.collection('daily_song_stats').snapshots().asyncMap((snap) async {
      final now = DateTime.now();
      final last3Days = [
        _formatDate(now),
        _formatDate(now.subtract(const Duration(days: 1))),
        _formatDate(now.subtract(const Duration(days: 2))),
      ];

      // 1. Cộng dồn lượt view của từng bài hát trong 3 ngày
      Map<String, int> songIdToViews = {};
      for (var doc in snap.docs) {
        final data = doc.data();
        if (last3Days.contains(data['date'])) {
          final songId = data['songId'];
          final views = (data['views'] ?? 0) as num;
          songIdToViews[songId] = (songIdToViews[songId] ?? 0) + views.toInt();
        }
      }

      // 2. Lấy toàn bộ bài hát để xử lý gộp trùng
      final songsSnapshot = await _db.collection('songs').get();
      Map<String, Map<String, dynamic>> aggregatedResults = {};

      for (var doc in songsSnapshot.docs) {
        final songData = doc.data();
        final songId = doc.id;
        final views = songIdToViews[songId] ?? 0;
        
        final title = (songData['title'] ?? '').toString().toLowerCase().trim();
        final artist = (songData['artist'] ?? '').toString().toLowerCase().trim();
        final key = '${title}_$artist';

        if (!aggregatedResults.containsKey(key)) {
          aggregatedResults[key] = {
            ...songData,
            'id': songId,
            'todayViews': views,
          };
        } else {
          // Cộng dồn view nếu bài hát trùng tên + nghệ sĩ (ví dụ bài trong album và single)
          aggregatedResults[key]!['todayViews'] += views;
        }
      }

      // 3. Sắp xếp và lấy Top
      final results = aggregatedResults.values.toList()
        ..sort((a, b) => (b['todayViews'] as int).compareTo(a['todayViews'] as int));

      // FALLBACK: Nếu 3 ngày qua hoàn toàn không có ai nghe bài nào, lấy Top mọi thời đại
      if (results.every((s) => s['todayViews'] == 0)) {
        final topSongs = await getTopSongs(limit: limit);
        return topSongs.map((s) => {...s, 'todayViews': s['totalViews']}).toList();
      }

      debugPrint('[TRENDING] Successfully sending ${results.length} unique songs to UI');
      return results.take(limit).toList();
    });
  }

  // --- CÁC HÀM TỐI ƯU KHÁC ---

  static Future<List<Map<String, dynamic>>> getTopSongs({int limit = 10, DateTime? since}) async {
    try {
      final snapshot = await _db.collection('view_stats').get();
      final stats = snapshot.docs.map((doc) => doc.data()).where((data) => data['targetType'] == 'song').toList();
      stats.sort((a, b) => ((b['totalViews'] ?? 0) as num).compareTo(a['totalViews'] ?? 0));
      List<Map<String, dynamic>> res = [];
      Set<String> seen = {};
      for (var data in stats) {
        if (res.length >= limit) break;
        final sDoc = await _db.collection('songs').doc(data['targetId']).get();
        if (sDoc.exists) {
          final sData = sDoc.data()!;
          final key = '${sData['title']}_${sData['artist']}'.toLowerCase().trim();
          if (!seen.contains(key)) { seen.add(key); res.add({...sData, 'id': sDoc.id, 'totalViews': data['totalViews']}); }
        }
      }
      return res;
    } catch (e) { return []; }
  }

  static Future<List<Map<String, dynamic>>> getTopAlbums({int limit = 10}) async {
    try {
      final statsSnap = await _db.collection('view_stats').get();
      final Map<String, int> songViews = {for (var doc in statsSnap.docs.where((d) => d.data()['targetType'] == 'song')) doc.data()['targetId']: ((doc.data()['totalViews'] ?? 0) as num).toInt()};
      final albumsSnap = await _db.collection('albums').get();
      final List<Map<String, dynamic>> albumList = [];
      for (var doc in albumsSnap.docs) {
        final data = doc.data();
        int views = 0;
        for (final sId in List<String>.from(data['songIds'] ?? [])) views += songViews[sId] ?? 0;
        albumList.add({...data, 'id': doc.id, 'totalViews': views});
      }
      albumList.sort((a, b) => (b['totalViews'] as int).compareTo(a['totalViews'] as int));
      return albumList.take(limit).toList();
    } catch (e) { return []; }
  }

  static Future<List<Map<String, dynamic>>> getTopArtists({int limit = 10, DateTime? since}) async {
    try {
      final snapshot = await _db.collection('view_stats').get();
      final stats = snapshot.docs.map((doc) => doc.data()).where((data) => data['targetType'] == 'artist').toList();
      stats.sort((a, b) => ((b['totalViews'] ?? 0) as num).compareTo(a['totalViews'] ?? 0));
      return stats.take(limit).map((data) => {'id': data['targetId'], 'totalViews': data['totalViews'] ?? 0}).toList();
    } catch (e) { return []; }
  }

  static Future<List<DailyStats>> getDailyStats({int days = 7}) async {
    try {
      final List<DailyStats> results = [];
      for (int i = 0; i < days; i++) {
        final d = DateTime.now().subtract(Duration(days: i));
        final snap = await _db.collection('daily_song_stats').where('date', isEqualTo: _formatDate(d)).get();
        int views = 0;
        for (var doc in snap.docs) views += ((doc.data()['views'] ?? 0) as num).toInt();
        results.add(DailyStats(date: d, songViews: views, albumViews: 0, artistViews: 0, totalListenTime: 0, uniqueUsers: 0));
      }
      return results.reversed.toList();
    } catch (e) { return []; }
  }

  static Stream<List<Map<String, dynamic>>> getArtistAnalyticsStream({int limit = 10}) {
    return _db.collection('view_stats').snapshots().asyncMap((snap) async {
      final List<Map<String, dynamic>> res = [];
      final docs = snap.docs.where((d) => d.data()['targetType'] == 'artist').toList();
      docs.sort((a, b) => ((b.data()['totalViews'] ?? 0) as num).compareTo(a.data()['totalViews'] ?? 0));
      for (var doc in docs.take(limit)) {
        final aDoc = await _db.collection('artists').doc(doc.data()['targetId']).get();
        if (aDoc.exists) res.add({...doc.data(), 'id': aDoc.id, 'name': aDoc.data()?['name'] ?? 'Unknown', 'avatarUrl': aDoc.data()?['avatarUrl']});
      }
      return res;
    });
  }

  static Future<List<ViewRecord>> getUserHistory(String userId, {int limit = 50}) async {
    try {
      final snap = await _db.collection('views').where('userId', isEqualTo: userId).get();
      final recs = snap.docs.map((doc) => ViewRecord(id: doc.id, targetType: ViewTargetType.song, targetId: doc.data()['targetId'] ?? '', userId: userId, viewedAt: (doc.data()['viewedAt'] as Timestamp).toDate(), durationSeconds: (doc.data()['durationSeconds'] as num?)?.toInt() ?? 0)).toList();
      recs.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
      return recs.take(limit).toList();
    } catch (e) { return []; }
  }

  static Stream<List<ViewRecord>> getUserHistoryStream(String userId, {int limit = 50}) {
    return _db.collection('views').where('userId', isEqualTo: userId).snapshots().map((snap) {
      final list = snap.docs.map((doc) => ViewRecord(id: doc.id, targetType: ViewTargetType.song, targetId: doc.data()['targetId'] ?? '', userId: userId, viewedAt: (doc.data()['viewedAt'] as Timestamp?)?.toDate() ?? DateTime.now(), durationSeconds: (doc.data()['durationSeconds'] as num?)?.toInt() ?? 0)).toList();
      list.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
      return list.take(limit).toList();
    });
  }

  static Future<List<Map<String, dynamic>>> getTrendingSongs24h({int limit = 20}) async {
    try {
      final today = _formatDate(DateTime.now());
      final snap = await _db.collection('daily_song_stats').where('date', isEqualTo: today).get();
      final List<Map<String, dynamic>> results = [];
      for (var doc in snap.docs) {
        final sDoc = await _db.collection('songs').doc(doc.data()['songId']).get();
        if (sDoc.exists) results.add({...sDoc.data()!, 'id': sDoc.id, 'todayViews': doc.data()['views']});
      }
      results.sort((a, b) => (b['todayViews'] as int).compareTo(a['todayViews'] as int));
      return results.take(limit).toList();
    } catch (e) { return []; }
  }

  static String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

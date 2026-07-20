import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/view_model.dart';

class ViewService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Track a view for any target
  static Future<void> trackView({
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

      // Update aggregate stats (increment counters)
      await _updateStats(targetType, targetId, userId, durationSeconds);

      // Cập nhật thống kê riêng theo ngày để tính Trending 24h
      if (targetType == ViewTargetType.song) {
        await _updateDailyTargetStats(targetId);
        await _incrementArtistStreamCount(targetId, userId, durationSeconds);
      }
    } catch (e) {
      debugPrint('Error tracking view: $e');
    }
  }

  /// Khi một bài hát được nghe, ta cộng dồn lượt stream cho TẤT CẢ Nghệ sĩ tham gia
  static Future<void> _incrementArtistStreamCount(String songId, String? userId, int durationSeconds) async {
    try {
      final songDoc = await _db.collection('songs').doc(songId).get();
      if (!songDoc.exists) return;
      
      final data = songDoc.data()!;
      // Xử lý cả artistIds (List) và artistId (String cũ)
      List<String> ids = [];
      if (data['artistIds'] is List) {
        ids = (data['artistIds'] as List).cast<String>();
      } else if (data['artistId'] is String) {
        ids = [data['artistId'] as String];
      }
      
      for (final artistId in ids) {
        if (artistId.isNotEmpty) {
          // Cập nhật view_stats cho từng nghệ sĩ (tổng lượt stream)
          await _updateStats(ViewTargetType.artist, artistId, userId, durationSeconds);
        }
      }
    } catch (e) {
      debugPrint('Error updating artist streams: $e');
    }
  }

  static Future<void> _updateDailyTargetStats(String songId) async {
    final today = _formatDate(DateTime.now());
    final docRef = _db.collection('daily_song_stats').doc('${songId}_$today');
    
    await docRef.set({
      'songId': songId,
      'date': today,
      'views': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<List<Map<String, dynamic>>> getTrendingSongs24h({int limit = 20}) async {
    try {
      final today = _formatDate(DateTime.now());
      final yesterday = _formatDate(DateTime.now().subtract(const Duration(days: 1)));

      // Lấy dữ liệu của cả hôm nay và hôm qua để tránh lệch múi giờ
      final snapshots = await Future.wait([
        _db.collection('daily_song_stats').where('date', isEqualTo: today).get(),
        _db.collection('daily_song_stats').where('date', isEqualTo: yesterday).get(),
      ]);

      // Gộp kết quả và cộng dồn lượt nghe cho các bài hát trùng tên + nghệ sĩ
      Map<String, Map<String, dynamic>> consolidatedResults = {};
      
      for (var snap in snapshots) {
        for (var doc in snap.docs) {
          final songId = doc.data()['songId'];
          final views = (doc.data()['views'] as num?)?.toInt() ?? 0;
          
          // Lấy thông tin bài hát để biết tên và nghệ sĩ
          final songDoc = await _db.collection('songs').doc(songId).get();
          if (songDoc.exists) {
            final songData = songDoc.data()!;
            final key = '${songData['title'].toString().toLowerCase()}_${songData['artist'].toString().toLowerCase()}';
            
            if (consolidatedResults.containsKey(key)) {
              // Cộng dồn view nếu đã tồn tại
              consolidatedResults[key]!['todayViews'] += views;
            } else {
              // Thêm mới nếu chưa có
              consolidatedResults[key] = {
                ...songData,
                'id': songDoc.id,
                'todayViews': views,
              };
            }
          }
        }
      }

      // Chuyển sang list và sắp xếp theo lượt nghe giảm dần sau khi đã cộng dồn
      List<Map<String, dynamic>> sortedResults = consolidatedResults.values.toList()
        ..sort((a, b) => (b['todayViews'] as int).compareTo(a['todayViews'] as int));

      return sortedResults.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting trending 24h: $e');
      return [];
    }
  }

  static Future<void> _updateArtistMonthlyListeners(String songId) async {
    // Hàm này sẽ không được gọi trực tiếp nữa, logic được gộp vào _incrementArtistStreamCount
  }

  // Update aggregate counters in Firestore
  static Future<void> _updateStats(
    ViewTargetType targetType,
    String targetId,
    String? userId,
    int durationSeconds,
  ) async {
    final statsRef = _db.collection('view_stats').doc('${targetType.name}_$targetId');

    await _db.runTransaction((transaction) async {
      final statsDoc = await transaction.get(statsRef);

      if (statsDoc.exists) {
        transaction.update(statsRef, {
          'totalViews': FieldValue.increment(1),
          'totalListenTime': FieldValue.increment(durationSeconds),
          'lastViewedAt': DateTime.now(),
        });
      } else {
        transaction.set(statsRef, {
          'targetType': targetType.name,
          'targetId': targetId,
          'totalViews': 1,
          'totalListenTime': durationSeconds,
          'lastViewedAt': DateTime.now(),
        });
      }
    });
  }

  // Get view stats for a specific target
  static Future<ViewStats> getViewStats(
    ViewTargetType targetType,
    String targetId,
  ) async {
    try {
      final statsDoc = await _db
          .collection('view_stats')
          .doc('${targetType.name}_$targetId')
          .get();

      if (!statsDoc.exists) {
        return ViewStats.empty(targetType, targetId);
      }

      final data = statsDoc.data()!;
      final viewedBy = (data['viewedBy'] as List?)?.cast<String>() ?? [];
      
      return ViewStats(
        targetType: targetType,
        targetId: targetId,
        totalViews: (data['totalViews'] as num?)?.toInt() ?? 0,
        totalListenTime: (data['totalListenTime'] as num?)?.toInt() ?? 0,
        lastViewedAt: data['lastViewedAt']?.toDate(),
      );
    } catch (e) {
      debugPrint('Error getting view stats: $e');
      return ViewStats.empty(targetType, targetId);
    }
  }

  // Get top songs by views
  static Future<List<Map<String, dynamic>>> getTopSongs({
    int limit = 10,
    DateTime? since,
  }) async {
    try {
      // Lấy tất cả bản ghi thống kê (không dùng where/orderBy để tránh lỗi Index)
      final snapshot = await _db.collection('view_stats').get();

      final List<Map<String, dynamic>> results = [];
      
      // Lọc bằng code Dart
      final songDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['targetType'] == 'song';
      }).toList();

      // Sắp xếp giảm dần theo lượt xem bằng code Dart
      songDocs.sort((a, b) {
        final viewsA = (a.data()['totalViews'] as num?)?.toInt() ?? 0;
        final viewsB = (b.data()['totalViews'] as num?)?.toInt() ?? 0;
        return viewsB.compareTo(viewsA);
      });

      // Lấy số lượng giới hạn
      final topDocs = songDocs.take(limit);

      for (var doc in topDocs) {
        final data = doc.data();
        final songId = data['targetId'] ?? doc.id.replaceFirst('song_', '');
        
        final songDoc = await _db.collection('songs').doc(songId).get();
        String title = 'Bài hát không tên';
        if (songDoc.exists) {
          title = songDoc.data()?['title'] ?? 'Bài hát không tên';
        }

        results.add(<String, dynamic>{
          ...data,
          'id': songId,
          'title': title,
        });
      }
      
      return results;
    } catch (e) {
      debugPrint('Error getting top songs: $e');
      return [];
    }
  }

  // Get top artists by views
  static Future<List<Map<String, dynamic>>> getTopArtists({
    int limit = 10,
    DateTime? since,
  }) async {
    try {
      Query query = _db.collection('view_stats')
          .where('targetType', isEqualTo: 'artist');

      if (since != null) {
        query = query.where('lastViewedAt', isGreaterThan: since);
      }

      final snapshot = await query
          .orderBy('totalViews', descending: true)
          .limit(limit)
          .get();

      final List<Map<String, dynamic>> results = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final artistId = data['targetId'] ?? doc.id.replaceFirst('artist_', '');

        // Truy xuất tên nghệ sĩ từ collection 'artists'
        final artistDoc = await _db.collection('artists').doc(artistId).get();
        String name = 'Nghệ sĩ ẩn danh';
        if (artistDoc.exists) {
          name = artistDoc.data()?['name'] ?? 'Nghệ sĩ ẩn danh';
        }

        results.add(<String, dynamic>{
          ...data,
          'id': artistId,
          'name': name,
        });
      }

      return results;
    } catch (e) {
      debugPrint('Error getting top artists: $e');
      return [];
    }
  }

  // Get daily stats
  static Future<List<DailyStats>> getDailyStats({
    int days = 7,
  }) async {
    try {
      final List<DailyStats> results = [];
      final now = DateTime.now();
      
      for (int i = 0; i < days; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = _formatDate(date);
        
        final snapshot = await _db.collection('daily_song_stats')
            .where('date', isEqualTo: dateStr)
            .get();
            
        int totalViews = 0;
        for (var doc in snapshot.docs) {
          totalViews += (doc.data()['views'] as num?)?.toInt() ?? 0;
        }
        
        results.add(DailyStats(
          date: DateTime(date.year, date.month, date.day),
          songViews: totalViews,
          albumViews: 0,
          artistViews: 0,
          totalListenTime: 0,
          uniqueUsers: 0,
        ));
      }
      
      return results.reversed.toList();
    } catch (e) {
      debugPrint('Error getting daily stats: $e');
      return [];
    }
  }

  // Get artist analytics stream (top 10 with resolved names)
  static Stream<List<Map<String, dynamic>>> getArtistAnalyticsStream({int limit = 10}) {
    return _db.collection('view_stats')
        .where('targetType', isEqualTo: 'artist')
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> results = [];
      
      // Filter and Sort in memory to avoid Index requirements
      final docs = snapshot.docs;
      docs.sort((a, b) => ((b.data()['totalViews'] as num?) ?? 0)
          .compareTo((a.data()['totalViews'] as num?) ?? 0));

      final topDocs = docs.take(limit);

      for (var doc in topDocs) {
        final data = doc.data();
        final artistId = data['targetId'] ?? doc.id.replaceFirst('artist_', '');
        
        final artistDoc = await _db.collection('artists').doc(artistId).get();
        final artistData = artistDoc.data();
        String name = artistDoc.exists ? (artistData?['name'] ?? 'Unknown') : 'Unknown';
        String? avatarUrl = artistDoc.exists ? (artistData?['avatarUrl'] ?? artistData?['imageUrl']) : null;

        results.add({
          ...data,
          'id': artistId,
          'name': name,
          'avatarUrl': avatarUrl,
          'totalViews': (data['totalViews'] as num?)?.toInt() ?? 0,
        });
      }
      return results;
    });
  }

  // Get user's listening history
  static Future<List<ViewRecord>> getUserHistory(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _db
          .collection('views')
          .where('userId', isEqualTo: userId)
          .orderBy('viewedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data()!;
        return ViewRecord(
          id: doc.id,
          targetType: ViewTargetType.values.firstWhere(
            (e) => e.name == data['targetType'],
            orElse: () => ViewTargetType.song,
          ),
          targetId: data['targetId'] ?? '',
          userId: data['userId'],
          viewedAt: data['viewedAt']?.toDate() ?? DateTime.now(),
          durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting user history: $e');
      return [];
    }
  }

  // Helpers
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static double _calculateAvgListenTime(Map<String, dynamic> data) {
    final total = (data['totalListenTime'] as num?)?.toInt() ?? 0;
    final views = (data['totalViews'] as num?)?.toInt() ?? 1;
    return views > 0 ? total / views : 0;
  }

  static Map<String, int> _parseViewsByDay(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
    return {};
  }

  static Map<String, int> _parseViewsByCountry(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
    return {};
  }

  // ==================== DATA SIMULATOR (DÀNH CHO TEST) ====================
  static Future<void> simulateFakeViews() async {
    try {
      final songsSnapshot = await _db.collection('songs').get();
      final artistsSnapshot = await _db.collection('artists').get();
      if (songsSnapshot.docs.isEmpty) return;

      final batch = _db.batch();
      final random = DateTime.now().millisecond;
      
      Map<String, String> artistNameToId = {
        for (var doc in artistsSnapshot.docs) 
          (doc.data()['name'] ?? '').toString().toLowerCase(): doc.id
      };

      for (var i = 0; i < songsSnapshot.docs.length; i++) {
        final songData = songsSnapshot.docs[i].data();
        final songId = songsSnapshot.docs[i].id;
        final title = (songData['title'] ?? '').toString().toLowerCase();
        
        // Lấy danh sách ID nghệ sĩ (hỗ trợ cả kiểu cũ String và kiểu mới List)
        List<String> currentArtistIds = [];
        if (songData['artistIds'] is List) {
          currentArtistIds = (songData['artistIds'] as List).cast<String>();
        } else if (songData['artistId'] is String) {
          currentArtistIds = [songData['artistId'] as String];
        }

        // Nếu trống ID, cố gắng tìm theo tên
        if (currentArtistIds.isEmpty) {
          final artistName = (songData['artist'] ?? '').toString().toLowerCase();
          final id = artistNameToId[artistName];
          if (id != null) currentArtistIds = [id];
        }
        
        // Số lượng view bơm thêm mỗi lần nhấn
        int extraViews = 50 + (random % 50); 
        if (title.contains('nhân danh tình yêu') || title.contains('not my fault') || title.contains('người đầu tiên')) {
          extraViews = 2000 + (random % 500); 
        }

        // 1. Cộng dồn vào daily_song_stats (Trending 24h)
        final today = _formatDate(DateTime.now());
        final dailyRef = _db.collection('daily_song_stats').doc('${songId}_$today');
        batch.set(dailyRef, {
          'songId': songId, 'date': today, 
          'views': FieldValue.increment(extraViews),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2. Cộng dồn vào view_stats (Tổng view & Biểu đồ)
        final songStatsRef = _db.collection('view_stats').doc('song_$songId');
        final simulatedListenTime = extraViews * 180; 
        batch.set(songStatsRef, {
          'targetType': 'song', 'targetId': songId,
          'totalViews': FieldValue.increment(extraViews),
          'totalListenTime': FieldValue.increment(simulatedListenTime),
          'lastViewedAt': DateTime.now(),
        }, SetOptions(merge: true));

        // 3. Cộng dồn cho TẤT CẢ Nghệ sĩ tham gia bài hát
        for (final artistId in currentArtistIds) {
          final artistStatsRef = _db.collection('view_stats').doc('artist_$artistId');
          batch.set(artistStatsRef, {
            'targetType': 'artist', 'targetId': artistId,
            'totalViews': FieldValue.increment(extraViews),
            'totalListenTime': FieldValue.increment(simulatedListenTime),
            'lastViewedAt': DateTime.now(),
          }, SetOptions(merge: true));

          final artistRef = _db.collection('artists').doc(artistId);
          batch.update(artistRef, {'monthlyListeners': FieldValue.increment(extraViews)});
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error simulating views: $e');
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum ViewTargetType { song, album, artist }

class ViewRecord {
  final String id;
  final ViewTargetType targetType;
  final String targetId;
  final String? userId;
  final DateTime viewedAt;
  final int durationSeconds; // Thời gian nghe/xem (0 = just opened)

  const ViewRecord({
    required this.id,
    required this.targetType,
    required this.targetId,
    this.userId,
    required this.viewedAt,
    this.durationSeconds = 0,
  });

  factory ViewRecord.create({
    required ViewTargetType targetType,
    required String targetId,
    String? userId,
    int durationSeconds = 0,
  }) {
    return ViewRecord(
      id: '${targetType.name}_${targetId}_${DateTime.now().millisecondsSinceEpoch}',
      targetType: targetType,
      targetId: targetId,
      userId: userId,
      viewedAt: DateTime.now(),
      durationSeconds: durationSeconds,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'targetType': targetType.name,
      'targetId': targetId,
      'userId': userId,
      'viewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'durationSeconds': durationSeconds,
    };
  }
}

class ViewStats {
  final ViewTargetType targetType;
  final String targetId;
  final int totalViews;
  final int totalListenTime; // seconds
  final DateTime? lastViewedAt;

  const ViewStats({
    required this.targetType,
    required this.targetId,
    required this.totalViews,
    required this.totalListenTime,
    this.lastViewedAt,
  });

  factory ViewStats.empty(ViewTargetType type, String targetId) {
    return ViewStats(
      targetType: type,
      targetId: targetId,
      totalViews: 0,
      totalListenTime: 0,
      lastViewedAt: null,
    );
  }
}

class DailyStats {
  final DateTime date;
  final int songViews;
  final int albumViews;
  final int artistViews;
  final int totalListenTime;
  final int uniqueUsers;

  const DailyStats({
    required this.date,
    required this.songViews,
    required this.albumViews,
    required this.artistViews,
    required this.totalListenTime,
    required this.uniqueUsers,
  });

  int get totalViews => songViews + albumViews + artistViews;
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/view_service.dart';

class AnalyticsProvider with ChangeNotifier {
  StreamSubscription? _subscription;
  List<Map<String, dynamic>> _topArtists = [];
  bool _isLoading = true;

  // Calculated Stats
  int _totalArtistViews = 0;
  String _mostViewedArtist = 'None';
  double _averageViews = 0.0;

  List<Map<String, dynamic>> get topArtists => _topArtists;
  bool get isLoading => _isLoading;
  int get totalArtistViews => _totalArtistViews;
  String get mostViewedArtist => _mostViewedArtist;
  double get averageViews => _averageViews;

  AnalyticsProvider() {
    _initStream();
  }

  void _initStream() {
    _subscription = ViewService.getArtistAnalyticsStream(limit: 10).listen((data) {
      _topArtists = data;
      _calculateStats();
      _isLoading = false;
      notifyListeners();
    });
  }

  void _calculateStats() {
    if (_topArtists.isEmpty) {
      _totalArtistViews = 0;
      _mostViewedArtist = 'N/A';
      _averageViews = 0.0;
      return;
    }

    _totalArtistViews = _topArtists.fold(0, (sum, item) => sum + (item['totalViews'] as int));
    _mostViewedArtist = _topArtists.first['name'] ?? 'Unknown';
    _averageViews = _totalArtistViews / _topArtists.length;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

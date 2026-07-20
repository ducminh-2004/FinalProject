import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/lyric_line.dart';
import '../providers/audio_provider.dart';
import '../services/lyrics_service.dart';

// ─── Editable row model ───────────────────────────────────────────────────────

class _Row {
  final TextEditingController timeCtrl;
  final TextEditingController textCtrl;

  _Row({int timeMs = 0, String text = ''})
      : timeCtrl = TextEditingController(text: _msToDisplay(timeMs)),
        textCtrl = TextEditingController(text: text);

  void dispose() {
    timeCtrl.dispose();
    textCtrl.dispose();
  }

  int get timeMs => _displayToMs(timeCtrl.text);

  LyricLine toLyricLine() =>
      LyricLine(timeMs: timeMs, text: textCtrl.text.trim());

  static String _msToDisplay(int ms) {
    final m = ms ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final cs = (ms % 1000) ~/ 10;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }

  static int _displayToMs(String s) {
    // Accept "mm:ss", "mm:ss.xx", "m:ss"
    final clean = s.trim();
    final parts = clean.split(':');
    if (parts.length < 2) return 0;
    final m = int.tryParse(parts[0]) ?? 0;
    final secParts = parts[1].split('.');
    final sec = int.tryParse(secParts[0]) ?? 0;
    final cs = secParts.length > 1 ? (int.tryParse(secParts[1]) ?? 0) : 0;
    return m * 60000 + sec * 1000 + cs * 10;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class LyricsEditorScreen extends StatefulWidget {
  final Song song;

  const LyricsEditorScreen({super.key, required this.song});

  @override
  State<LyricsEditorScreen> createState() => _LyricsEditorScreenState();
}

class _LyricsEditorScreenState extends State<LyricsEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Line-by-line state ──
  final List<_Row> _rows = [];
  final ScrollController _listScroll = ScrollController();

  // ── LRC paste state ──
  final TextEditingController _lrcCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  static const _primary = Color(0xFF0E6B5A);
  static const _dark = Color(0xFF0A1F1A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExisting();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _listScroll.dispose();
    _lrcCtrl.dispose();
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  Future<void> _loadExisting() async {
    final lines = await LyricsService.fetchLyrics(widget.song.id);
    if (!mounted) return;
    setState(() {
      _rows.clear();
      for (final l in lines) _rows.add(_Row(timeMs: l.timeMs, text: l.text));
      _lrcCtrl.text = LyricsService.toLrc(lines);
      _isLoading = false;
    });
  }

  List<LyricLine> _buildLinesFromRows() {
    final out = _rows
        .map((r) => r.toLyricLine())
        .where((l) => l.text.isNotEmpty)
        .toList()
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return out;
  }

  List<LyricLine> _buildLinesFromLrc() =>
      LyricsService.parseLrc(_lrcCtrl.text);

  void _syncLrcToRows() {
    final lines = _buildLinesFromLrc();
    for (final r in _rows) r.dispose();
    _rows
      ..clear()
      ..addAll(lines.map((l) => _Row(timeMs: l.timeMs, text: l.text)));
  }

  void _syncRowsToLrc() {
    _lrcCtrl.text = LyricsService.toLrc(_buildLinesFromRows());
  }

  Future<void> _save() async {
    List<LyricLine> lines;
    if (_tabController.index == 0) {
      lines = _buildLinesFromLrc();
    } else {
      lines = _buildLinesFromRows();
    }

    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có dòng lời nào hợp lệ để lưu')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await LyricsService.uploadLyrics(widget.song.id, lines);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu lời bài hát thành công'),
            backgroundColor: _primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu: $e')),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _deleteLyrics() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa lời bài hát',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            const Text('Bạn có chắc muốn xóa toàn bộ lời bài hát này?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await LyricsService.deleteLyrics(widget.song.id);
      if (!mounted) return;
      for (final r in _rows) r.dispose();
      setState(() {
        _rows.clear();
        _lrcCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa lời bài hát')),
      );
    }
  }

  // ── Line-by-line actions ─────────────────────────────────────────────────

  void _addRow({int timeMs = 0, String text = ''}) {
    setState(() => _rows.add(_Row(timeMs: timeMs, text: text)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listScroll.hasClients) {
        _listScroll.animateTo(
          _listScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _captureTime(int positionMs) {
    // Tạm dừng 200ms để user thấy timestamp được chụp
    _addRow(timeMs: positionMs);
    // Focus text field mới thêm ngay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rows.isNotEmpty) {
        FocusScope.of(context)
            .requestFocus(FocusNode()); // unfocus current
      }
    });
  }

  void _deleteRow(int index) {
    _rows[index].dispose();
    setState(() => _rows.removeAt(index));
  }

  void _sortRows() {
    setState(() {
      _rows.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _dark, size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lời bài hát',
                style: TextStyle(
                    color: _dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
            Text(
              widget.song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _dark.withOpacity(0.45), fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (!_isLoading && (_rows.isNotEmpty || _lrcCtrl.text.isNotEmpty))
            IconButton(
              onPressed: _deleteLyrics,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              tooltip: 'Xóa lời nhạc',
            ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _primary)),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text('Lưu',
                      style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primary,
          unselectedLabelColor: _dark.withOpacity(0.4),
          indicatorColor: _primary,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          onTap: (i) {
            // Sync data when switching tabs
            if (i == 1 && _lrcCtrl.text.isNotEmpty) _syncLrcToRows();
            if (i == 0 && _rows.isNotEmpty) _syncRowsToLrc();
          },
          tabs: const [
            Tab(text: 'Nhập LRC'),
            Tab(text: 'Từng câu'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primary))
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildLrcTab(),
                _buildLineByLineTab(),
              ],
            ),
    );
  }

  // ── Tab 1: LRC Paste ─────────────────────────────────────────────────────

  Widget _buildLrcTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: _primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Định dạng LRC',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _primary,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        '[mm:ss.xx] Nội dung lời\n[00:12.00] Blinding lights are fading\n[00:17.50] You know I\'m standing here',
                        style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: _dark.withOpacity(0.55),
                            height: 1.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lấy file .lrc từ: lrclib.net, megalobiz.com, syair.info',
                        style: TextStyle(
                            fontSize: 11,
                            color: _dark.withOpacity(0.4)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _dark.withOpacity(0.07)),
            ),
            child: TextField(
              controller: _lrcCtrl,
              maxLines: null,
              minLines: 15,
              style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  height: 1.6),
              decoration: InputDecoration(
                hintText:
                    '[00:12.00] Dòng đầu tiên\n[00:17.50] Dòng thứ hai\n...',
                hintStyle: TextStyle(
                    color: _dark.withOpacity(0.2), fontSize: 12),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ── Tab 2: Line-by-line ──────────────────────────────────────────────────

  Widget _buildLineByLineTab() {
    return Column(
      children: [
        _buildMiniPlayer(),
        Expanded(
          child: _rows.isEmpty
              ? _buildEmptyRows()
              : ReorderableListView.builder(
                  scrollController: _listScroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _rows.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final row = _rows.removeAt(oldIndex);
                      _rows.insert(newIndex, row);
                    });
                  },
                  itemBuilder: (ctx, i) =>
                      _buildRowItem(_rows[i], i, key: ValueKey(i)),
                ),
        ),
        _buildRowToolbar(),
      ],
    );
  }

  Widget _buildEmptyRows() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music_rounded,
              size: 64, color: _dark.withOpacity(0.08)),
          const SizedBox(height: 16),
          Text('Chưa có câu nào',
              style: TextStyle(
                  color: _dark.withOpacity(0.3),
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Bấm "Thêm câu" hoặc chụp thời gian khi bài đang phát',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _dark.withOpacity(0.25), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRowItem(_Row row, int index, {required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: _dark.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.drag_indicator_rounded,
                color: Colors.black26, size: 20),
          ),
          // Time field
          SizedBox(
            width: 78,
            child: TextField(
              controller: row.timeCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: _primary),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                hintText: '00:00.00',
                hintStyle:
                    TextStyle(fontSize: 11, color: Colors.black26),
              ),
            ),
          ),
          Container(width: 1, height: 36, color: Colors.black.withOpacity(0.08)),
          // Lyrics text
          Expanded(
            child: TextField(
              controller: row.textCtrl,
              style: const TextStyle(fontSize: 14, height: 1.4),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintText: 'Nội dung câu hát...',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.black26),
              ),
            ),
          ),
          // Delete button
          InkWell(
            onTap: () => _deleteRow(index),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.remove_circle_outline_rounded,
                  color: Colors.redAccent, size: 20),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // Mini player: shows when AudioProvider has a song loaded
  Widget _buildMiniPlayer() {
    return Consumer<AudioProvider>(
      builder: (ctx, audio, _) {
        final isThisSong = audio.currentSong?.id == widget.song.id;
        final hasAnySong = audio.hasSong;
        final posMs = audio.position.inMilliseconds;

        return Container(
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Play/pause for this song
              InkWell(
                onTap: () {
                  if (isThisSong) {
                    audio.togglePlayPause();
                  } else {
                    audio.playSong(widget.song);
                  }
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    (isThisSong && audio.isPlaying)
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Position display
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isThisSong
                          ? _formatMs(posMs)
                          : (hasAnySong
                              ? 'Bài khác đang phát'
                              : 'Bấm ▶ để phát bài này'),
                      style: TextStyle(
                        fontSize: isThisSong ? 16 : 13,
                        fontWeight: isThisSong
                            ? FontWeight.w800
                            : FontWeight.w500,
                        fontFamily: isThisSong ? 'monospace' : null,
                        color: isThisSong
                            ? _primary
                            : _dark.withOpacity(0.4),
                      ),
                    ),
                    if (isThisSong)
                      Text(
                        '→ Bấm "Chụp" để ghi thời gian hiện tại',
                        style: TextStyle(
                            fontSize: 11,
                            color: _dark.withOpacity(0.35)),
                      ),
                  ],
                ),
              ),
              // Sort button
              IconButton(
                onPressed: _sortRows,
                icon: const Icon(Icons.sort_rounded,
                    color: Colors.black38, size: 20),
                tooltip: 'Sắp xếp theo thời gian',
              ),
              // Capture button
              if (isThisSong)
                ElevatedButton.icon(
                  onPressed: () => _captureTime(posMs),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(_formatMs(posMs),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRowToolbar() {
    return Container(
      color: Colors.white,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _addRow(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm câu trống'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Lưu lời nhạc'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMs(int ms) {
    final m = ms ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final cs = (ms % 1000) ~/ 10;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }
}

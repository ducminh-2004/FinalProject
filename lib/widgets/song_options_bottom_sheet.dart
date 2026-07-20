import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/user_provider.dart';
import '../firebase/firestore_service.dart';

class SongOptionsBottomSheet extends StatelessWidget {
  final Song song;

  const SongOptionsBottomSheet({super.key, required this.song});

  static void show(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SongOptionsBottomSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isLiked = userProvider.isSongLiked(song.id);
    const mintGreen = Color(0xFF0E6B5A);
    const darkText = Color(0xFF0A1F1A);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: darkText.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Song Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: mintGreen.withValues(alpha: 0.1),
                  ),
                  child: song.coverUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(song.coverUrl!, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.music_note_rounded, color: mintGreen, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song.artist,
                        style: TextStyle(
                          color: darkText.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),

          // Actions
          _buildOption(
            context,
            icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            iconColor: isLiked ? mintGreen : darkText.withValues(alpha: 0.7),
            title: isLiked ? 'Xóa khỏi yêu thích' : 'Thêm vào yêu thích',
            onTap: () {
              userProvider.toggleLike(song.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isLiked ? 'Đã xóa khỏi yêu thích' : 'Đã thêm vào yêu thích'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _buildOption(
            context,
            icon: Icons.playlist_add_rounded,
            title: 'Thêm vào playlist',
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylistSheet(context, song);
            },
          ),
          _buildOption(
            context,
            icon: Icons.download_rounded,
            title: 'Tải xuống',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tính năng tải xuống sắp có!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _buildOption(
            context,
            icon: Icons.share_rounded,
            title: 'Chia sẻ',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tính năng chia sẻ sắp có!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? const Color(0xFF0A1F1A).withValues(alpha: 0.7)),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF0A1F1A),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AddToPlaylistSheet(song: song),
    );
  }
}

class _AddToPlaylistSheet extends StatelessWidget {
  final Song song;

  const _AddToPlaylistSheet({required this.song});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    const mintGreen = Color(0xFF0E6B5A);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Thêm vào playlist',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A1F1A),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          Flexible(
            child: StreamBuilder<List<Playlist>>(
              stream: FirestoreService.watchUserPlaylists(userProvider.userId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final playlists = snapshot.data ?? [];
                if (playlists.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Bạn chưa có playlist nào'),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // logic tạo playlist có thể thêm ở đây
                          },
                          child: const Text('Tạo playlist mới', style: TextStyle(color: mintGreen)),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: mintGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.queue_music_rounded, color: mintGreen),
                      ),
                      title: Text(
                        playlist.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${playlist.songIds.length} bài hát'),
                      onTap: () async {
                        await FirestoreService.addSongToPlaylist(playlist.id, song.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã thêm "${song.title}" vào "${playlist.title}"'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

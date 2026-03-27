import 'package:flutter/material.dart';
import '../models/video.dart';
import '../models/user_playlist.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/video_card.dart';
import '../widgets/common_widgets.dart';
import 'player_screen.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<UserPlaylist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() => _loading = true);
    try {
      final pls = await _api.getUserPlaylists();
      if (mounted) setState(() { _playlists = pls; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('새 플레이리스트', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '플레이리스트 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                await _api.createUserPlaylist(name);
                if (context.mounted) Navigator.pop(ctx);
                _loadPlaylists();
              }
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(UserPlaylist playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('플레이리스트 삭제'),
        content: Text('"${playlist.name}"을(를) 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await _api.deleteUserPlaylist(playlist.id);
              if (context.mounted) Navigator.pop(ctx);
              _loadPlaylists();
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text('플레이리스트', style: Theme.of(context).textTheme.titleLarge),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('새 플레이리스트', style: TextStyle(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _playlists.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: AppTheme.accent,
                  onRefresh: _loadPlaylists,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _playlists.length,
                    itemBuilder: (_, i) {
                      final pl = _playlists[i];
                      final color = AppTheme.getChannelColor(i);
                      return TapScale(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _PlaylistDetailScreen(playlist: pl),
                          ),
                        ).then((_) => _loadPlaylists()),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child:
                                    Icon(Icons.queue_music, color: color, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pl.name,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: color.withOpacity(0.9))),
                                    const SizedBox(height: 2),
                                    Text('${pl.itemCount}개 영상',
                                        style: const TextStyle(
                                            color: AppTheme.textTertiary,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.textTertiary),
                                onPressed: () => _showDeleteDialog(pl),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.playlist_add, color: AppTheme.accent, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('플레이리스트가 없습니다',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('영상을 모아 나만의 플레이리스트를 만들어보세요',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Playlist Detail ─────────────────────────────────────────────────────────

class _PlaylistDetailScreen extends StatefulWidget {
  final UserPlaylist playlist;
  const _PlaylistDetailScreen({required this.playlist});

  @override
  State<_PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<_PlaylistDetailScreen> {
  final ApiService _api = ApiService();
  late List<UserPlaylistItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.playlist.items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(widget.playlist.name,
            style: Theme.of(context).textTheme.titleLarge),
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined,
                      size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: 12),
                  const Text('아직 영상이 없습니다',
                      style: TextStyle(color: AppTheme.textTertiary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item = _items[i];
                final v = Video(
                  videoid: item.videoid,
                  channelId: item.channelId,
                  channelName: item.channelName,
                  title: item.title,
                  thumbnail: item.thumbnail,
                );
                return Dismissible(
                  key: Key(item.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: AppTheme.accent.withOpacity(0.1),
                    child: const Icon(Icons.delete, color: AppTheme.accent),
                  ),
                  onDismissed: (_) async {
                    setState(() => _items.removeAt(i));
                    await _api.removeVideoFromUserPlaylist(
                        widget.playlist.id, item.videoid);
                  },
                  child: VideoListTile(
                    video: v,
                    onTap: () {
                      final allVideos = _items
                          .map((e) => Video(
                                videoid: e.videoid,
                                channelId: e.channelId,
                                channelName: e.channelName,
                                title: e.title,
                                thumbnail: e.thumbnail,
                              ))
                          .toList();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(
                            video: v,
                            playlistVideos: allVideos,
                            initialIndex: i,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

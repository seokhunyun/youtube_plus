import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/video.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/channel_card.dart';
import '../widgets/video_card.dart';
import '../widgets/common_widgets.dart';
import 'player_screen.dart';
import 'channel_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  List<Channel> _favorites = [];
  List<Video> _latestVideos = [];
  List<Video> _favLatestVideos = [];
  bool _loadingFav = true;
  bool _loadingLatest = true;
  bool _loadingFavLatest = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingFav = true;
      _loadingLatest = true;
      _loadingFavLatest = true;
    });
    try {
      final favs = await _api.getFavoriteChannels();
      if (mounted) setState(() { _favorites = favs; _loadingFav = false; });

      // Latest from favorites channels
      if (favs.isNotEmpty) {
        try {
          final ids = favs.map((c) => c.channelId).toList();
          final vids = await _api.getLatestVideos(limit: 20, channelIds: ids);
          if (mounted) setState(() { _favLatestVideos = vids; _loadingFavLatest = false; });
        } catch (_) {
          if (mounted) setState(() => _loadingFavLatest = false);
        }
      } else {
        if (mounted) setState(() => _loadingFavLatest = false);
      }
    } catch (_) {
      if (mounted) setState(() { _loadingFav = false; _loadingFavLatest = false; });
    }

    try {
      final vids = await _api.getLatestVideos(limit: 20);
      if (mounted) setState(() { _latestVideos = vids; _loadingLatest = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingLatest = false);
    }
  }

  void _openPlayer(Video video, List<Video> playlist, int index) {
    _api.addToHistory(video);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          video: video,
          playlistVideos: playlist,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppTheme.surface,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'YouTube Plus',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                        ),
                  ),
                ],
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Favorites Section ────────────────
                  const SectionHeader(title: '즐겨찾기 채널'),
                  if (_loadingFav)
                    const ShimmerChannelRow()
                  else if (_favorites.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: AppTheme.accent),
                            const SizedBox(width: 12),
                            Text(
                              '검색 탭에서 채널을 즐겨찾기에 추가해보세요',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _favorites.length,
                        itemBuilder: (_, i) => ChannelCard(
                          channel: _favorites[i],
                          cardColor: AppTheme.getChannelColor(i),
                          isFavorite: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChannelScreen(channel: _favorites[i]),
                            ),
                          ).then((_) => _loadData()),
                          onFavoriteToggle: () async {
                            await _api.removeFavoriteChannel(
                                _favorites[i].channelId);
                            _loadData();
                          },
                        ),
                      ),
                    ),

                  // ── Favorites Latest Videos ──────────
                  if (_favorites.isNotEmpty) ...[
                    const SectionHeader(title: '즐겨찾기 최신 영상'),
                    if (_loadingFavLatest)
                      const ShimmerVideoRow()
                    else if (_favLatestVideos.isEmpty)
                      const SizedBox.shrink()
                    else
                      SizedBox(
                        height: 190,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _favLatestVideos.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: VideoCard(
                              video: _favLatestVideos[i],
                              onTap: () => _openPlayer(
                                  _favLatestVideos[i], _favLatestVideos, i),
                            ),
                          ),
                        ),
                      ),
                  ],

                  // ── All Latest Videos ────────────────
                  const SectionHeader(title: '전체 최신 영상'),
                  if (_loadingLatest)
                    const ShimmerVideoRow()
                  else
                    SizedBox(
                      height: 190,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _latestVideos.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: VideoCard(
                            video: _latestVideos[i],
                            onTap: () =>
                                _openPlayer(_latestVideos[i], _latestVideos, i),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

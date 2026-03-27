import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/video.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/video_card.dart';
import '../widgets/common_widgets.dart';
import 'player_screen.dart';
import 'channel_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final TextEditingController _queryCtrl = TextEditingController();
  late TabController _tabCtrl;

  List<Channel> _channelResults = [];
  List<Video> _videoResults = [];
  List<Channel> _favorites = [];
  bool _searchingChannels = false;
  bool _searchingVideos = false;
  String _lastQuery = '';
  String _sortMode = 'date_desc';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favs = await _api.getFavoriteChannels();
      if (mounted) setState(() => _favorites = favs);
    } catch (_) {}
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _channelResults = [];
        _videoResults = [];
        _lastQuery = '';
      });
      return;
    }
    _lastQuery = q;
    setState(() { _searchingChannels = true; _searchingVideos = true; });

    try {
      final channels = await _api.searchChannels(q);
      if (mounted && q == _lastQuery) {
        setState(() { _channelResults = channels; _searchingChannels = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _searchingChannels = false);
    }

    try {
      final videos = await _api.searchVideos(q, sort: _sortMode);
      if (mounted && q == _lastQuery) {
        setState(() { _videoResults = videos; _searchingVideos = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _searchingVideos = false);
    }
  }

  bool _isFavorite(String channelId) =>
      _favorites.any((c) => c.channelId == channelId);

  Future<void> _toggleFavorite(Channel channel) async {
    if (_isFavorite(channel.channelId)) {
      await _api.removeFavoriteChannel(channel.channelId);
    } else {
      await _api.addFavoriteChannel(channel);
    }
    await _loadFavorites();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text('검색', style: Theme.of(context).textTheme.titleLarge),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textTertiary,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: '채널'),
            Tab(text: '영상'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextFormField(
              controller: _queryCtrl,
              decoration: InputDecoration(
                hintText: '채널명 또는 영상 제목 검색...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textTertiary),
                suffixIcon: _queryCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textTertiary),
                        onPressed: () {
                          _queryCtrl.clear();
                          _search('');
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {});
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (_queryCtrl.text == val) _search(val);
                });
              },
              onFieldSubmitted: _search,
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ── Channel Tab ────────────────────────
                _buildChannelTab(),
                // ── Video Tab ──────────────────────────
                _buildVideoTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTab() {
    if (_lastQuery.isEmpty) {
      return _buildEmptySearch('채널명을 입력해 검색하세요');
    }
    if (_searchingChannels) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_channelResults.isEmpty) {
      return _buildEmptySearch('검색 결과가 없습니다');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _channelResults.length,
      itemBuilder: (_, i) {
        final ch = _channelResults[i];
        final fav = _isFavorite(ch.channelId);
        return TapScale(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChannelScreen(channel: ch)),
          ).then((_) => _loadFavorites()),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: ch.thumbnail != null
                      ? Image.network(ch.thumbnail!,
                          width: 46, height: 46, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _channelPlaceholder(ch, i))
                      : _channelPlaceholder(ch, i),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ch.channelName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      if (ch.ranking != null)
                        Text('랭킹 #${ch.ranking}',
                            style: const TextStyle(
                                color: AppTheme.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      fav ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey(fav),
                      color: fav ? AppTheme.accent : AppTheme.textTertiary,
                    ),
                  ),
                  onPressed: () => _toggleFavorite(ch),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _channelPlaceholder(Channel ch, int i) {
    return Container(
      width: 46,
      height: 46,
      color: AppTheme.getChannelColor(i),
      child: Center(
        child: Text(
          ch.channelName.isNotEmpty ? ch.channelName[0].toUpperCase() : 'C',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildVideoTab() {
    if (_lastQuery.isEmpty) {
      return _buildEmptySearch('영상 제목을 입력해 검색하세요');
    }
    return Column(
      children: [
        // Sort options
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('정렬: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              _sortChip('최신순', 'date_desc'),
              const SizedBox(width: 8),
              _sortChip('오래된순', 'date_asc'),
            ],
          ),
        ),
        Expanded(
          child: _searchingVideos
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent))
              : _videoResults.isEmpty
                  ? _buildEmptySearch('검색 결과가 없습니다')
                  : ListView.builder(
                      itemCount: _videoResults.length,
                      itemBuilder: (_, i) {
                        final v = _videoResults[i];
                        return VideoListTile(
                          video: v,
                          onTap: () {
                            _api.addToHistory(v);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  video: v,
                                  playlistVideos: _videoResults,
                                  initialIndex: i,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _sortChip(String label, String value) {
    final selected = _sortMode == value;
    return GestureDetector(
      onTap: () {
        if (_sortMode != value) {
          setState(() => _sortMode = value);
          _search(_lastQuery);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearch(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(
                  color: AppTheme.textTertiary, fontSize: 15)),
        ],
      ),
    );
  }
}

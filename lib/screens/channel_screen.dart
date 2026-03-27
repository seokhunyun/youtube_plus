import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/video.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/video_card.dart';
import '../widgets/common_widgets.dart';
import 'player_screen.dart';

class ChannelScreen extends StatefulWidget {
  final Channel channel;

  const ChannelScreen({super.key, required this.channel});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  final ApiService _api = ApiService();
  List<Video> _videos = [];
  bool _loading = true;
  bool _isFavorite = false;
  final ScrollController _scrollController = ScrollController();
  final int _limit = 50;
  int _offset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  String _sort = 'date_desc';
  int _colorIndex = 0;

  Channel? _fullChannelInfo;

  @override
  void initState() {
    super.initState();
    _colorIndex = widget.channel.channelId.codeUnits.fold(0, (a, b) => a + b) %
        AppTheme.channelPalette.length;
    _scrollController.addListener(_onScroll);
    _loadChannelInfo(); // Fetch full live stats (like videoCnt)
    _loadVideos();
    _checkFavorite();
  }

  Future<void> _loadChannelInfo() async {
    try {
      final info = await _api.getChannel(widget.channel.channelId);
      if (mounted) setState(() => _fullChannelInfo = info);
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 500 &&
        !_loading &&
        !_loadingMore &&
        _hasMore) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loading = true;
      _offset = 0;
      _hasMore = true;
    });
    try {
      final videos = await _api.getChannelVideos(widget.channel.channelId,
          limit: _limit, offset: _offset, sort: _sort);
      if (mounted) {
        setState(() {
          _videos = videos;
          _loading = false;
          _hasMore = videos.length == _limit;
          _offset += _limit;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreVideos() async {
    setState(() => _loadingMore = true);
    try {
      final moreVideos = await _api.getChannelVideos(widget.channel.channelId,
          limit: _limit, offset: _offset, sort: _sort);
      if (mounted) {
        setState(() {
          _videos.addAll(moreVideos);
          _loadingMore = false;
          _hasMore = moreVideos.length == _limit;
          _offset += _limit;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _checkFavorite() async {
    try {
      final favs = await _api.getFavoriteChannels();
      if (mounted) {
        setState(() {
          _isFavorite = favs.any((c) => c.channelId == widget.channel.channelId);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await _api.removeFavoriteChannel(widget.channel.channelId);
    } else {
      await _api.addFavoriteChannel(widget.channel);
    }
    setState(() => _isFavorite = !_isFavorite);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatCount(int cnt) {
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    Function mathFunc = (Match match) => '${match[1]},';
    return cnt.toString().replaceAllMapped(reg, (Match match) => '${match[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AppTheme.getChannelColor(_colorIndex);
    
    // Use fresh channel info from API if available, else fallback to passed channel info, then to _videos.length
    final displayCnt = _fullChannelInfo?.videoCnt ?? widget.channel.videoCnt ?? _videos.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Channel Header ───────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: cardColor.withOpacity(0.9),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cardColor,
                      cardColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: 40,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    // Channel info
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 80, 20, 20),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.3),
                              border: Border.all(
                                  color: Colors.white, width: 2.5),
                            ),
                            child: ClipOval(
                              child: widget.channel.thumbnail != null
                                  ? Image.network(
                                      widget.channel.thumbnail!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    )
                                  : const Icon(Icons.person,
                                      color: Colors.white, size: 32),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.channel.channelName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (widget.channel.ranking != null)
                                  Text(
                                    '랭킹 #${widget.channel.ranking}',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withOpacity(0.8),
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    key: ValueKey(_isFavorite),
                    color: Colors.white,
                  ),
                ),
                onPressed: _toggleFavorite,
              ),
            ],
          ),

          // ── Sort bar ────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.surface,
              child: Row(
                children: [
                  Text(
                      '${_formatCount(displayCnt)}개 영상',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  const Spacer(),
                  _sortChip('최신순', 'date_desc', cardColor),
                  const SizedBox(width: 8),
                  _sortChip('오래된순', 'date_asc', cardColor),
                ],
              ),
            ),
          ),

          // ── Video List ───────────────────────────────
          if (_loading)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ShimmerCard(height: 80),
                ),
                childCount: 8,
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => VideoListTile(
                  video: _videos[i],
                  onTap: () {
                    _api.addToHistory(_videos[i]);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(
                          video: _videos[i],
                          playlistVideos: _videos,
                          initialIndex: i,
                        ),
                      ),
                    );
                  },
                ),
                childCount: _videos.length,
              ),
            ),
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accent)),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String value, Color accent) {
    final sel = _sort == value;
    return GestureDetector(
      onTap: () {
        if (_sort != value) {
          setState(() => _sort = value);
          _loadVideos();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? accent : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

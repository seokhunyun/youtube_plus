import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'channel_screen.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<Channel> _channels = [];
  List<Channel> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final favs = await _api.getFavoriteChannels();
      final channels = await _api.getChannels(limit: 100, offset: 0);
      if (mounted) {
        setState(() {
          _favorites = favs;
          _channels = channels;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
    // Re-fetch favorites rather than full reload to avoid screen jump
    final favs = await _api.getFavoriteChannels();
    if (mounted) setState(() => _favorites = favs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          '채널 랭킹 TOP 100',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        elevation: 0,
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              color: AppTheme.accent,
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _channels.length,
                itemBuilder: (_, i) {
                  final ch = _channels[i];
                  final fav = _isFavorite(ch.channelId);
                  final isTop3 = i < 3;
                  
                  return TapScale(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChannelScreen(channel: ch)),
                    ).then((_) => _loadData()),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isTop3 
                            ? [
                                BoxShadow(
                                  color: AppTheme.getChannelColor(i).withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Ranking Number
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: isTop3 ? 24 : 18,
                                fontWeight: isTop3 ? FontWeight.w900 : FontWeight.bold,
                                color: isTop3 ? AppTheme.getChannelColor(i) : AppTheme.textTertiary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Thumbnail
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: isTop3 ? Border.all(color: AppTheme.getChannelColor(i), width: 2.5) : null,
                            ),
                            child: ClipOval(
                              child: ch.thumbnail != null
                                  ? Image.network(
                                      ch.thumbnail!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _channelPlaceholder(ch, i),
                                    )
                                  : _channelPlaceholder(ch, i),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ch.channelName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                if (ch.videoCnt != null)
                                  Text(
                                    '영상 ${_formatCount(ch.videoCnt!)}개',
                                    style: const TextStyle(
                                        color: AppTheme.textTertiary, fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                          // Favorite Toggle
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
              ),
            ),
    );
  }

  String _formatCount(int cnt) {
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return cnt.toString().replaceAllMapped(reg, (Match match) => '${match[1]},');
  }

  Widget _channelPlaceholder(Channel ch, int i) {
    return Container(
      color: AppTheme.getChannelColor(i),
      child: Center(
        child: Text(
          ch.channelName.isNotEmpty ? ch.channelName[0].toUpperCase() : 'C',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
    );
  }
}

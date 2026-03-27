import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:palette_generator/palette_generator.dart';
import '../models/video.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/video_card.dart';

class PlayerScreen extends StatefulWidget {
  final Video video;
  final List<Video>? playlistVideos;
  final int? initialIndex;

  const PlayerScreen({
    super.key,
    required this.video,
    this.playlistVideos,
    this.initialIndex,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  late YoutubePlayerController _controller;
  final ApiService _apiService = ApiService();
  bool _autoPlayNext = true;
  Color _bgColor = AppTheme.background;
  Color _accentColor = AppTheme.accent;
  late AnimationController _colorAnimController;
  late Animation<Color?> _bgAnimation;
  Color _prevBgColor = AppTheme.background;
  late int _currentIndex;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 이어보기
  bool _hasSeeked = false;          // 한 번만 seek
  bool _resumePositionLoaded = false; // 위치 로드 완료 여부
  bool _playerEverPlayed = false;    // 플레이어가 playing 상태 진입 여부
  double _resumePosition = 0;       // 복원할 위치(초)
  Timer? _progressTimer;            // 5초마다 위치 저장
  String _currentVideoid = '';

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    _currentVideoid = widget.video.videoid;

    _colorAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bgAnimation =
        ColorTween(begin: AppTheme.background, end: AppTheme.background)
            .animate(CurvedAnimation(
                parent: _colorAnimController, curve: Curves.easeInOut));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initPlayer(widget.video);
    _extractColor(widget.video);
    _loadResumePosition(widget.video.videoid);
  }

  // ── 플레이어 초기화 ─────────────────────────────────────────
  void _initPlayer(Video video) {
    _controller = YoutubePlayerController.fromVideoId(
      videoId: video.videoid,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        origin: 'https://www.youtube-nocookie.com',
      ),
    );

    _controller.listen((state) {
      // 처음 playing 상태가 됐을 때 seek 시도
      if (!_playerEverPlayed &&
          state.playerState == PlayerState.playing) {
        _playerEverPlayed = true;
        _trySeek(); // 위치가 이미 로드됐으면 바로 seek
      }

      // 영상 종료
      if (state.playerState == PlayerState.ended) {
        _apiService.saveWatchProgress(_currentVideoid, 0);
        _stopProgressTimer();
        _playNext();
      }

      // 재생 중일 때만 타이머 활성화
      if (state.playerState == PlayerState.playing) {
        _startProgressTimer();
      } else {
        _stopProgressTimer();
      }
    });
  }

  // ── seek 시도 (race condition 해결: 양쪽에서 호출) ──────────
  /// 위치 로드 완료 AND 플레이어가 playing 상태 진입 – 둘 다 됐을 때만 seek
  void _trySeek() {
    if (_hasSeeked) return;
    if (!_resumePositionLoaded || !_playerEverPlayed) return;
    if (_resumePosition <= 5) return; // 5초 이하는 처음부터
    _hasSeeked = true;
    _controller.seekTo(seconds: _resumePosition, allowSeekAhead: true);
  }

  // ── 이어보기 위치 로드 ───────────────────────────────────────
  Future<void> _loadResumePosition(String videoid) async {
    final pos = await _apiService.getWatchProgress(videoid);
    if (!mounted) return;
    setState(() {
      _resumePosition = pos;
      _resumePositionLoaded = true;
    });
    // 플레이어가 이미 playing 상태라면 즉시 seek
    _trySeek();
  }

  // ── 위치 저장 타이머 ─────────────────────────────────────────
  void _startProgressTimer() {
    if (_progressTimer?.isActive == true) return;
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final currentTime = await _controller.currentTime;
        if (currentTime > 0) {
          _apiService.saveWatchProgress(_currentVideoid, currentTime);
        }
      } catch (_) {}
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  // ── 현재 위치 즉시 저장 ──────────────────────────────────────
  Future<void> _saveCurrentProgress() async {
    try {
      final currentTime = await _controller.currentTime;
      if (currentTime > 5) {
        await _apiService.saveWatchProgress(_currentVideoid, currentTime);
      }
    } catch (_) {}
  }

  // ── 색상 추출 ────────────────────────────────────────────────
  Future<void> _extractColor(Video video) async {
    if (video.thumbnail == null) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(video.thumbnail!),
        size: const Size(200, 112),
      );
      final dominant = palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          AppTheme.accent;
      final newBg = Color.fromARGB(
        30,
        dominant.red,
        dominant.green,
        dominant.blue,
      );
      if (mounted) {
        _prevBgColor = _bgColor;
        _bgAnimation = ColorTween(begin: _prevBgColor, end: newBg).animate(
            CurvedAnimation(
                parent: _colorAnimController, curve: Curves.easeInOut));
        _colorAnimController.forward(from: 0);
        setState(() {
          _bgColor = newBg;
          _accentColor = dominant;
        });
      }
    } catch (_) {}
  }

  // ── 다음 영상 ────────────────────────────────────────────────
  void _playNext() {
    final videos = widget.playlistVideos;
    if (!_autoPlayNext || videos == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final nextIndex = _currentIndex + 1;
    if (nextIndex < videos.length) {
      _playVideo(videos[nextIndex], nextIndex);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  // ── 영상 전환 ────────────────────────────────────────────────
  Future<void> _playVideo(Video video, int index) async {
    await _saveCurrentProgress();
    _stopProgressTimer();

    final savedPos = await _apiService.getWatchProgress(video.videoid);
    if (!mounted) return;

    _controller.loadVideoById(videoId: video.videoid);
    _extractColor(video);
    _apiService.addToHistory(video);

    setState(() {
      _currentIndex = index;
      _currentVideoid = video.videoid;
      _resumePosition = savedPos;
      _resumePositionLoaded = true;
      _playerEverPlayed = false; // 새 영상은 playing 이벤트 다시 기다림
      _hasSeeked = savedPos <= 5;
    });
  }

  @override
  void dispose() {
    _stopProgressTimer();
    // 앱 종료/뒤로가기 시 현재 위치 저장
    _saveCurrentProgress();
    _colorAnimController.dispose();
    _pulseController.dispose();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = widget.playlistVideos;
    final hasNext = videos != null && _currentIndex < videos.length - 1;
    final currentVideo = videos != null ? videos[_currentIndex] : widget.video;

    return AnimatedBuilder(
      animation: Listenable.merge([_colorAnimController, _pulseController]),
      builder: (context, child) {
        return Stack(
          children: [
            // 1. Base vibrant color
            Container(color: _bgAnimation.value ?? AppTheme.background),

            // 2. Ambilight Effect: Dynamically pulsing blurred thumbnail
            if (currentVideo.thumbnail != null)
              Positioned.fill(
                child: Opacity(
                  opacity: _pulseAnimation.value,
                  child: Image.network(
                    currentVideo.thumbnail!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // 3. Heavy backdrop filter
            if (currentVideo.thumbnail != null)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.black.withOpacity(0.15)),
                ),
              ),

            // 4. Main UI Scaffold
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  currentVideo.title ?? 'Playing',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  // 이어보기 배지
                  if (_resumePosition > 5)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Chip(
                        backgroundColor: _accentColor.withOpacity(0.15),
                        label: Text(
                          '이어보기 ${_formatDuration(_resumePosition)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: _accentColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (hasNext)
                    Row(
                      children: [
                        Text(
                          '연속재생',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        Switch(
                          value: _autoPlayNext,
                          activeColor: _accentColor,
                          onChanged: (val) => setState(() => _autoPlayNext = val),
                        ),
                      ],
                    ),
                ],
              ),
              body: child,
            ),
          ],
        );
      },
      child: Column(
        children: [
          // YouTube Player
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: YoutubePlayer(
                controller: _controller,
                aspectRatio: 16 / 9,
              ),
            ),
          ),
          // Video info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentVideo.title ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (currentVideo.channelName != null)
                  Text(
                    currentVideo.channelName!,
                    style: TextStyle(
                      color: _accentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          // Up next list
          if (videos != null && videos.length > 1) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '다음 영상',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: videos.length,
                itemBuilder: (context, i) {
                  final v = videos[i];
                  final isPlaying = i == _currentIndex;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPlaying ? _accentColor.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: VideoListTile(
                      video: v,
                      onTap: () => _playVideo(v, i),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final d = Duration(seconds: seconds.toInt());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

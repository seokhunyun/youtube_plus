import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

class VideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  final double width;
  final double imageHeight;

  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.width = 168,
    this.imageHeight = 98,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: video.thumbnail ?? '',
                width: width,
                height: imageHeight,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: width,
                  height: imageHeight,
                  color: AppTheme.surfaceVariant,
                ),
                errorWidget: (_, __, ___) => Container(
                  width: width,
                  height: imageHeight,
                  color: AppTheme.surfaceVariant,
                  child: const Icon(Icons.play_circle_outline,
                      color: Colors.grey, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              video.title ?? '',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            // Channel + date
            Text(
              [
                if (video.channelName != null) video.channelName!,
                if (video.publishedAt != null)
                  DateFormat('yyyy.MM.dd').format(video.publishedAt!),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class VideoListTile extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  const VideoListTile({
    super.key,
    required this.video,
    required this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: video.thumbnail ?? '',
                width: 120,
                height: 70,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(width: 120, height: 70, color: AppTheme.surfaceVariant),
                errorWidget: (_, __, ___) =>
                    Container(width: 120, height: 70, color: AppTheme.surfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title ?? '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (video.channelName != null) video.channelName!,
                      if (video.publishedAt != null)
                        DateFormat('yyyy.MM.dd').format(video.publishedAt!),
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (onMore != null)
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppTheme.textTertiary),
                onPressed: onMore,
              ),
          ],
        ),
      ),
    );
  }
}

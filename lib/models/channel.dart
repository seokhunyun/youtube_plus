class Channel {
  final String channelId;
  final String channelName;
  final int? category;
  final int? videoCnt;
  final int? ranking;
  final String? thumbnail;

  Channel({
    required this.channelId,
    required this.channelName,
    this.category,
    this.videoCnt,
    this.ranking,
    this.thumbnail,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      channelId: json['channel_id'] ?? '',
      channelName: json['channel_name'] ?? '',
      category: json['category'],
      videoCnt: json['video_cnt'],
      ranking: json['ranking'],
      thumbnail: json['thumbnail'],
    );
  }

  Map<String, dynamic> toJson() => {
    'channel_id': channelId,
    'channel_name': channelName,
    'thumbnail': thumbnail,
  };
}

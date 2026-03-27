class Video {
  final String videoid;
  final String? channelId;
  final String? channelName;
  final String? title;
  final String? description;
  final String? thumbnail;
  final DateTime? publishedAt;

  Video({
    required this.videoid,
    this.channelId,
    this.channelName,
    this.title,
    this.description,
    this.thumbnail,
    this.publishedAt,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      videoid: json['videoid'] ?? '',
      channelId: json['channel_id'],
      channelName: json['channel_name'],
      title: json['title'],
      description: json['description'],
      thumbnail: json['thumbnail'],
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'videoid': videoid,
    'channel_id': channelId,
    'channel_name': channelName,
    'title': title,
    'thumbnail': thumbnail,
  };
}

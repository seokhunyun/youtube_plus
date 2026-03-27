class UserPlaylist {
  final int id;
  final String name;
  final String? description;
  final DateTime? createdAt;
  final List<UserPlaylistItem> items;
  int itemCount;

  UserPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
    this.items = const [],
    this.itemCount = 0,
  });

  factory UserPlaylist.fromJson(Map<String, dynamic> json) {
    return UserPlaylist(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => UserPlaylistItem.fromJson(e))
          .toList(),
      itemCount: json['item_count'] ?? 0,
    );
  }
}

class UserPlaylistItem {
  final int id;
  final int playlistId;
  final String videoid;
  final String? title;
  final String? thumbnail;
  final String? channelId;
  final String? channelName;

  UserPlaylistItem({
    required this.id,
    required this.playlistId,
    required this.videoid,
    this.title,
    this.thumbnail,
    this.channelId,
    this.channelName,
  });

  factory UserPlaylistItem.fromJson(Map<String, dynamic> json) {
    return UserPlaylistItem(
      id: json['id'],
      playlistId: json['playlist_id'],
      videoid: json['videoid'] ?? '',
      title: json['title'],
      thumbnail: json['thumbnail'],
      channelId: json['channel_id'],
      channelName: json['channel_name'],
    );
  }
}

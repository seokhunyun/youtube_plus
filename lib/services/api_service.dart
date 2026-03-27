import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/video.dart';
import '../models/user_playlist.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8765';
    try {
      if (Platform.isAndroid) return 'http://b-611.iptime.org:8765';
    } catch (_) {}
    return 'http://localhost:8765';
  }

  Future<T> _get<T>(String path, T Function(dynamic) parser) async {
    final response = await http.get(Uri.parse('$baseUrl$path'));
    if (response.statusCode == 200) {
      return parser(json.decode(utf8.decode(response.bodyBytes)));
    }
    throw Exception('Failed: $path (${response.statusCode})');
  }

  Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed POST: $path (${response.statusCode})');
  }

  Future<void> _delete(String path) async {
    await http.delete(Uri.parse('$baseUrl$path'));
  }

  // ── Channels ──────────────────────────────────────────────
  Future<List<Channel>> getChannels({int limit = 50, int offset = 0}) =>
      _get('/channels?limit=$limit&offset=$offset',
          (d) => (d as List).map((e) => Channel.fromJson(e)).toList());

  Future<List<Channel>> searchChannels(String q) =>
      _get('/channels/search?q=${Uri.encodeComponent(q)}',
          (d) => (d as List).map((e) => Channel.fromJson(e)).toList());

  Future<Channel> getChannel(String channelId) =>
      _get('/channels/$channelId', (d) => Channel.fromJson(d));

  Future<List<Video>> getChannelVideos(String channelId,
      {int limit = 30, int offset = 0, String sort = 'date_desc'}) =>
      _get('/channels/$channelId/videos?limit=$limit&offset=$offset&sort=$sort',
          (d) => (d as List).map((e) => Video.fromJson(e)).toList());

  // ── Videos ────────────────────────────────────────────────
  Future<List<Video>> getLatestVideos(
      {int limit = 20, List<String>? channelIds}) {
    String path = '/videos/latest?limit=$limit';
    if (channelIds != null && channelIds.isNotEmpty) {
      path += '&channel_ids=${channelIds.join(",")}';
    }
    return _get(path, (d) => (d as List).map((e) => Video.fromJson(e)).toList());
  }

  Future<List<Video>> searchVideos(String q,
      {String? channelId, String sort = 'date_desc', int limit = 50, int offset = 0}) {
    String path =
        '/videos/search?q=${Uri.encodeComponent(q)}&sort=$sort&limit=$limit&offset=$offset';
    if (channelId != null) path += '&channel_id=$channelId';
    return _get(path, (d) => (d as List).map((e) => Video.fromJson(e)).toList());
  }

  // ── History ───────────────────────────────────────────────
  Future<List<Video>> getHistory({int limit = 20}) =>
      _get('/history?limit=$limit',
          (d) => (d as List).map((e) => Video.fromJson(e)).toList());

  Future<void> addToHistory(Video video) =>
      _post('/history', video.toJson()).then((_) {});

  // ── Favorites ─────────────────────────────────────────────
  Future<List<Channel>> getFavoriteChannels() =>
      _get('/favorites/channels',
          (d) => (d as List).map((e) => Channel.fromJson(e)).toList());

  Future<void> addFavoriteChannel(Channel channel) =>
      _post('/favorites/channels', channel.toJson()).then((_) {});

  Future<void> removeFavoriteChannel(String channelId) =>
      _delete('/favorites/channels/$channelId');

  // ── User Playlists ────────────────────────────────────────
  Future<List<UserPlaylist>> getUserPlaylists() =>
      _get('/user-playlists',
          (d) => (d as List).map((e) => UserPlaylist.fromJson(e)).toList());

  Future<int> createUserPlaylist(String name, {String description = ''}) async {
    final res = await _post('/user-playlists', {'name': name, 'description': description});
    return res['id'];
  }

  Future<void> deleteUserPlaylist(int id) => _delete('/user-playlists/$id');

  Future<void> addVideoToUserPlaylist(int playlistId, Video video) =>
      _post('/user-playlists/$playlistId/videos', video.toJson()).then((_) {});

  Future<void> removeVideoFromUserPlaylist(int playlistId, String videoid) =>
      _delete('/user-playlists/$playlistId/videos/$videoid');

  // ── Watch Progress ────────────────────────────────────────
  /// Returns saved position in seconds (0 if never watched)
  Future<double> getWatchProgress(String videoid) async {
    try {
      final res = await _get('/watch-progress/$videoid', (d) => d);
      return (res['position_seconds'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> saveWatchProgress(String videoid, double positionSeconds,
      {double? durationSeconds}) async {
    try {
      await _post('/watch-progress', {
        'videoid': videoid,
        'position_seconds': positionSeconds,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
      });
    } catch (_) {}
  }
}

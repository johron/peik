import 'package:peik/type/playlist_data.dart';

import 'configuration_data.dart';

class UserData {
  final String username;
  final String? pin;
  final List<PlaylistData> playlists;
  final ConfigurationData configuration;

  const UserData({
    required this.username,
    required this.playlists,
    required this.configuration,
    this.pin,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'playlists': playlists.map((playlist) => playlist.toJson()).toList(),
      'configuration': configuration.toJson(),
      'pin': pin,
    };
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      username: json['username'],
      pin: json['pin'],
      playlists: (json['playlists'] as List<dynamic>)
          .map((playlistJson) => PlaylistData.fromJson(playlistJson))
          .toList(),
      configuration:
          ConfigurationData.fromJson(json['configuration']),
    );
  }

  UserData copyWith({
    String? username,
    String? pin,
    List<PlaylistData>? playlists,
    ConfigurationData? configuration,
  }) {
    return UserData(
      username: username ?? this.username,
      pin: pin ?? this.pin,
      playlists: playlists ?? this.playlists,
      configuration: configuration ?? this.configuration,
    );
  }
}
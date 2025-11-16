import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:peik/controller/storage_controller.dart';
import 'package:peik/type/playlist_data.dart';
import 'package:peik/type/song_data.dart';

import '../type/stream_data.dart';

PlaylistData getSamplePlaylist() {
  return PlaylistData(
    uuid: generatePlaylistUUID('Playlist 1'),
    title: 'Playlist 1',
    songs: [
      SongData(
        title: "Holy Diver",
        artist: "Dio",
        album: "Holy Diver",
        added: DateTime(1983, 5, 25),
        duration: Duration(minutes: 5, seconds: 52),
        uuid: 'sample-uuid-0',
      ),
      getSampleSong(1),
      getSampleSong(2),
      getSampleSong(3),
    ],
    created: DateTime.now().subtract(Duration(days: 30)),
    lastUpdate: DateTime.now(),
  );
}

SongData getSampleSong(int num) {
  return SongData(
      title: "Song $num",
      artist: "Artist $num",
      album: "Album $num",
      added: DateTime.now(),
      duration: Duration(minutes: 3, seconds: num * 10),
      uuid: 'sample-uuid-$num',
  );
}

String getPlaylistPath(PlaylistData playlist) {
  return "sample_stream/${playlist.title}";
  //return '${playlist.repo}/${playlist.title}';
}

double calculateTitleFontSize(String title) {
  int length = title.length;

  if (length <= 10) {
    // For titles with 10 or fewer characters
    // Scale up to maximum of 80 for shorter titles
    return 72 + (10 - length) * 0.8; // 0.8 = (80-72)/10
  } else {
    // For titles longer than 10 characters
    // Scale down as length increases
    return math.max(30.0, 72 - (length - 10) * 2);
  }
}

Duration multiplyDuration(Duration duration, double factor) {
  return Duration(milliseconds: (duration.inMilliseconds * factor).round());
}

String getMissingAlbumArtPath() {
  return 'https://community.spotify.com/t5/image/serverpage/image-id/55829iC2AD64ADB887E2A5/image-size/large?v=v2&px=999';
}

StreamData getSampleStreamData() {
  return StreamData(
    lastUpdate: DateTime.now().millisecondsSinceEpoch,
    version: "2025-1.0", token: "token123",
    users: [],
    songs: [],
  );
}

String generatePlaylistUUID(String title) {
  var time = DateTime.now().microsecondsSinceEpoch;
  var randomPart = math.Random().nextInt(100000);
  var uuid0 = '$title-$time-$randomPart';
  return base64Url.encode(uuid0.codeUnits);
}

String generateSongUUID(String title, String artist, String album) {
  var time = DateTime.now().millisecondsSinceEpoch;
  var randomPart = math.Random().nextInt(100000);
  var uuid0 = '$title-$artist-$time-$randomPart';
  //var url = base64Url.encode(uuid0.codeUnits);
  // use the 40 last characters, remove the first ones if too long
  if (uuid0.length > 40) {
    uuid0 = uuid0.substring(uuid0.length - 40);
  }
  return base64Url.encode(uuid0.codeUnits);
}

Future<void> carefulShowDialog({required BuildContext context, required WidgetBuilder builder}) async {
  if (context.mounted) {
    showDialog(context: context, builder: builder);
  }
}

double getSongDurationValue(double position, double total) {
  if (total == 0) return 0;
  var value = position / total;
  return value;
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:path_provider/path_provider.dart';
import 'package:peik/controller/auth_controller.dart';
import 'package:peik/type/local_store.dart';
import 'package:peik/type/song_data.dart';
import 'package:peik/type/stream_data.dart';
import 'package:peik/util/constants.dart';
import 'package:peik/util/ffmpeg.dart';
import 'package:process_run/process_run.dart';

import '../type/user_data.dart';

class StorageController {
  StorageController._internal();

  static final StorageController _instance = StorageController._internal();

  factory StorageController() => _instance;

  final AuthController auth = AuthController();

  final _songAddedController = StreamController<SongData>.broadcast();
  final _songRemovedController = StreamController<String>.broadcast();

  Stream<SongData> get onSongAdded => _songAddedController.stream;
  Stream<String> get onSongRemoved => _songRemovedController.stream;

  late String localPath;

  Future<void> init() async {
    var streamData = await loadStream();
    if (streamData == null) {
      var initialStream = StreamData(
        lastUpdate: DateTime
            .now()
            .millisecondsSinceEpoch,
        version: version,
        token: auth.hashSha256(auth.generateToken()!),
        users: [],
        songs: [],
      );
      await saveStream(initialStream);
    }

    localPath = await _localPath;
  }

  Future<String> get _localPath async {
    // Linux: ~/.config/peik
    // Windows: %APPDATA%\Peik
    // macOS: ~/Library/Application Support/Peik
    // Android/iOS and others: use path_provider

    if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '.';
      final dir = Directory('$home/.config/peik');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    }

    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? Platform.environment['USERPROFILE'] ?? '.';
      final dir = Directory('$appData${Platform.pathSeparator}peik');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    }

    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '.';
      final dir = Directory('$home/Library/Application Support/peik');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    }

    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _streamFile async {
    final path = await _localPath;
    // Make sure the directory exists
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('$path/stream.json');
  }

  Future<File> saveStream(StreamData data) async {
    final file = await _streamFile;
    final String stream = jsonEncode(data);
    final res = file.writeAsString(stream);

    return res;
  }

  Future<StreamData?> loadStream() async {
    try {
      final file = await _streamFile;
      final String contents = await file.readAsString();
      final Map<String, dynamic> jsonData = jsonDecode(contents);
      return StreamData.fromJson(jsonData);
    } catch (e) {
      print('Error loading stream data: $e');
      return null;
    }
  }

  Future<File> get _localStoreFile async {
    final path = await _localPath;
    // Make sure the directory exists
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('$path/local.json');
  }

  Future<File> saveLocalStore(LocalStore data) async {
    final file = await _localStoreFile;
    final String store = jsonEncode(data);
    return file.writeAsString(store);
  }

  Future<LocalStore?> loadLocalStore() async {
    try {
      final file = await _localStoreFile;
      final String contents = await file.readAsString();
      final Map<String, dynamic> jsonData = jsonDecode(contents);
      return LocalStore.fromJson(jsonData);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveSongFile(String songUUID, List<int> bytes) async {
    final path = await _localPath;
    final dir = Directory('$path/songs');
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('$path/songs/$songUUID.flac');
    await file.writeAsBytes(bytes);

    if (!file.path.endsWith('.flac')) {
      await convertToFlac(file.path);
      await file.delete();
    }

    return true;
  }

  Future<bool> deleteSongFile(String songUUID) async {
    final path = await getSongFilePath(songUUID);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  Future<String> getSongFilePath(String songUUID) async {
    var path = "${await _localPath}/songs/$songUUID.flac";
    return path;
  }

  Future<bool> addUser(UserData user) async {
    var stream = await loadStream();
    if (stream == null) {
      print("No stream data available to add user.");
      return false;
    }

    var newStream = stream;
    newStream.users.add(user);

    saveStream(newStream);

    print("User ${user.username} added successfully.");

    return true;
  }

  Future<bool> addSong(SongData song, String path, String method) async {
    var stream = await loadStream();
    if (stream == null) {
      print("No stream data available to add song.");
      return false;
    }

    switch (method) {
      case "From File": {
        final file = File(path);
        if (!await file.exists()) {
          print("File at path $path does not exist.");
          return false;
        }
        final bytes = await file.readAsBytes();
        await saveSongFile(song.uuid, bytes);
      }
      case "From URL": {
        // get file with http:
        final uri = Uri.parse(path);
        final response = await http.get(uri);
        if (response.statusCode != 200) {
          print("Failed to download file from URL $path. Status code: ${response
              .statusCode}");
          return false;
        }
        await saveSongFile(song.uuid, response.bodyBytes);
      }
      case "From YouTube": {
        print("YouTube import method not implemented yet.");
        return false;
      }
    }

    // precalculate duration with ffprobe
    var duration = await getDuration(await getSongFilePath(song.uuid));

    song = SongData(
      uuid: song.uuid,
      title: song.title,
      artist: song.artist,
      album: song.album,
      added: song.added,
      duration: duration,
    );

    var newStream = stream;
    newStream.songs.add(song);

    await saveStream(newStream);
    _songAddedController.add(song);

    print("Song ${song.title} added successfully.");

    return true;
  }

  Future<bool> removeSong(String songUUID) async {
    var stream = await loadStream();
    if (stream == null) {
      print("No stream data available to remove song.");
      return false;
    }

    var newStream = stream;
    newStream.songs.removeWhere((song) => song.uuid == songUUID);

    for (var user in newStream.users) {
      var updatedPlaylists = user.playlists.map((playlist) {
        var updatedSongs = playlist.songs.where((song) => song.uuid != songUUID).toList();
        return playlist.copyWith(songs: updatedSongs);
      }).toList();
      var updatedUser = user.copyWith(playlists: updatedPlaylists);
      newStream.users[newStream.users.indexOf(user)] = updatedUser;
      await saveStream(newStream);
    }

    await saveStream(newStream);
    _songRemovedController.add(songUUID);

    await deleteSongFile(songUUID);

    print("Song with UUID $songUUID removed successfully.");

    return true;
  }

  bool setToken(String token) {
    loadStream().then((data) {
      if (data == null) {
        print("No stream data available to set token.");
        return false;
      }

      if (data.token != "") {
        print("Token is already set.");
        return false;
      }

      var newStream = data;
      newStream = StreamData(
        lastUpdate: newStream.lastUpdate,
        version: newStream.version,
        token: token,
        users: newStream.users,
        songs: newStream.songs,
      );

      saveStream(newStream);

      print("Token set successfully.");
      return true;
    });

    return true;
  }
}
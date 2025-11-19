import 'dart:async';

import 'package:peik/controller/auth_controller.dart';
import 'package:peik/controller/storage_controller.dart';
import 'package:peik/util/util.dart';

import '../type/local_store.dart';
import '../type/page.dart';
import '../type/playlist_data.dart';
import '../type/song_data.dart';
import '../type/stream_data.dart';
import '../type/user_data.dart';

class UserController {
  UserController._internal();

  static final UserController _instance = UserController._internal();

  factory UserController() => _instance;

  final AuthController auth = AuthController();
  final StorageController storage = StorageController();

  final _userUpdateController = StreamController<UserData>.broadcast();
  final _userDeletePlaylistController = StreamController<void>.broadcast();

  StreamController<OPage> userSelectedPageController = StreamController<OPage>.broadcast();

  Stream<UserData> get onUserUpdated => _userUpdateController.stream;
  Stream<void> get onUserDeletedPlaylist => _userDeletePlaylistController.stream;
  Stream<OPage> get onUserSelectedPage => userSelectedPageController.stream;

  // getter for AuthController find loggedInUser
  Future<UserData> get user async {
    var authUser = auth.loggedInUser;
    if (authUser == null) {
      throw Exception("No user is logged in");
    }

    var stream = await storage.loadStream();
    var user = stream?.users.firstWhere((u) => u.username == authUser.user.username);
    if (user == null) {
      throw Exception("Logged in user not found in storage");
    }

    return user;
}

  Future<bool> createPlaylist(String title, String description) async {
    var stream = await storage.loadStream();
    if (stream == null) {
      return false;
    }

    var user = await this.user;

    var newPlaylist = PlaylistData(
      uuid: generatePlaylistUUID(title),
      title: title,
      description: description,
      songs: [],
      created: DateTime.now(),
      lastUpdate: DateTime.now(),
    );

    var updatedPlaylists = List<PlaylistData>.from(user.playlists)..add(newPlaylist);
    var updatedUser = UserData(
      username: user.username,
      pin: user.pin,
      playlists: updatedPlaylists,
      configuration: user.configuration,
    );

    updateUser(updatedUser);

    return true;
  }

  Future<bool> deletePlaylist(String playlistUUID) async {
    var stream = await storage.loadStream();
    if (stream == null) {
      return false;
    }

    var user = await this.user;
    var updatedPlaylists = user.playlists.where((p) => p.uuid != playlistUUID).toList();
    var updatedUser = UserData(
      username: user.username,
      pin: user.pin,
      playlists: updatedPlaylists,
      configuration: user.configuration,
    );
    updateUser(updatedUser);

    _userDeletePlaylistController.add(null);

    return true;
  }

  Future<void> updatePlaylist(PlaylistData updatedPlaylist) async {
    var stream = await storage.loadStream();
    if (stream == null) {
      return;
    }

    var user = await this.user;
    var updatedPlaylists = user.playlists.map((p) {
      if (p.uuid == updatedPlaylist.uuid) {
        return updatedPlaylist;
      }
      return p;
    }).toList();

    var updatedUser = UserData(
      username: user.username,
      pin: user.pin,
      playlists: updatedPlaylists,
      configuration: user.configuration,
    );

    await updateUser(updatedUser);
    return;
  }

  void addSongToPlaylist(String songUUID, String playlistUUID) async {
    var stream = await storage.loadStream();
    if (stream == null) {
      return;
    }

    var song = await getSongFromUUID(songUUID);
    if (song == null) {
      print("Song with UUID $songUUID not found");
      return;
    }

    var user = await this.user;
    var updatedPlaylists = user.playlists.map((p) {
      if (p.uuid == playlistUUID) {
        var updatedSongs = List<SongData>.from(p.songs)..add(song);
        return PlaylistData(
          uuid: p.uuid,
          title: p.title,
          description: p.description,
          songs: updatedSongs,
          created: p.created,
          lastUpdate: DateTime.now(),
        );
      }
      return p;
    }).toList();

    var updatedUser = UserData(
      username: user.username,
      pin: user.pin,
      playlists: updatedPlaylists,
      configuration: user.configuration,
    );

    await updateUser(updatedUser);
  }

  void removeSongFromPlaylist(String songUUID, String playlistUUID) async {
    var stream = await storage.loadStream();
    if (stream == null) {
      return;
    }

    var user = await this.user;
    var updatedPlaylists = user.playlists.map((p) {
      if (p.uuid == playlistUUID) {
        var updatedSongs = p.songs.where((s) => s.uuid != songUUID).toList();
        return PlaylistData(
          uuid: p.uuid,
          title: p.title,
          description: p.description,
          songs: updatedSongs,
          created: p.created,
          lastUpdate: DateTime.now(),
        );
      }
      return p;
    }).toList();

    var updatedUser = UserData(
      username: user.username,
      pin: user.pin,
      playlists: updatedPlaylists,
      configuration: user.configuration,
    );

    await updateUser(updatedUser);
  }

  Future<SongData?> getSongFromUUID(String songUUID) async {
    var stream = await storage.loadStream();
    if (stream == null) {
      return null;
    }

    try {
      return stream.songs.firstWhere((s) => s.uuid == songUUID);
    } catch (e) {
      return null;
    }
  }

  Future<PlaylistData?> getPlaylistByUUID(String playlistUUID) async {
    var user = await this.user;

    try {
      return user.playlists.firstWhere((p) => p.uuid == playlistUUID);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateUser(UserData updatedUser) async {
    var stream = await storage.loadStream();
    if (stream == null) {
      return;
    }

    var updatedUsers = stream.users.map((u) {
      if (u.username == updatedUser.username) {
        return updatedUser;
      }
      return u;
    }).toList();

    var updatedStream = StreamData(
      lastUpdate: stream.lastUpdate,
      version: stream.version,
      token: stream.token,
      users: updatedUsers,
      songs: stream.songs,
    );

    _userUpdateController.add(updatedUser);

    await storage.saveStream(updatedStream);
  }

  Future<void> pinPlaylist(String playlistUUID) async {
    var localStore = await storage.loadLocalStore();
    if (localStore == null) {
      return;
    }

    var updatedPinnedPlaylists = List<String>.from(localStore.pinnedPlaylists);
    if (!updatedPinnedPlaylists.contains(playlistUUID)) {
      updatedPinnedPlaylists.add(playlistUUID);
    }

    var updatedLocalStore = LocalStore(
      loggedInUser: localStore.loggedInUser,
      pinnedPlaylists: updatedPinnedPlaylists,
    );

    await storage.saveLocalStore(updatedLocalStore);
    _userUpdateController.add(await user);
  }

  Future<void> unpinPlaylist(String playlistUUID) async {
    var localStore = await storage.loadLocalStore();
    if (localStore == null) {
      return;
    }

    var updatedPinnedPlaylists = localStore.pinnedPlaylists.where((p) => p != playlistUUID).toList();

    var updatedLocalStore = LocalStore(
      loggedInUser: localStore.loggedInUser,
      pinnedPlaylists: updatedPinnedPlaylists,
    );

    await storage.saveLocalStore(updatedLocalStore);
    _userUpdateController.add(await user);
  }

  Future<List<String>> getPinnedPlaylists() async {
    var localStore = await storage.loadLocalStore();
    if (localStore == null) {
      return [];
    }
    return localStore.pinnedPlaylists;
  }
}
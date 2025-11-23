// dart
import 'dart:async';
import 'dart:collection';

import 'package:just_audio/just_audio.dart';
import 'package:peik/controller/storage_controller.dart';
import 'package:peik/controller/user_controller.dart';
import 'package:peik/type/playlist_data.dart';
import 'package:peik/type/song_data.dart';

enum PlaybackState {
  playing,
  paused,
  stopped,
  loading,
  error,
}

class PlaybackController {
  PlaybackController._internal();

  static final PlaybackController _instance = PlaybackController._internal();

  factory PlaybackController() => _instance;

  final AudioPlayer _player = AudioPlayer();

  PlaybackState _state = PlaybackState.stopped;
  bool _shuffle = false;
  bool _repeat = false;
  double _position = 0;
  double _volume = 0.7;
  bool _muted = false;
  List<String> _extraQueue = [];
  List<String> _playlistQueue = [];
  List<String> _previousQueue = [];
  (SongData, bool)? _currentSong;

  PlaybackState get state => _state;
  bool get isShuffling => _shuffle;
  bool get isRepeating => _repeat;
  double get position => _position;
  double get currentVolume => _volume;
  bool get isMuted => _muted;
  List<String> get extraQueue => _extraQueue;
  List<String> get playlistQueue => _playlistQueue;
  List<String> get previousQueue => _previousQueue;
  SongData? get currentSong => _currentSong?.$1;

  final _playbackStateController = StreamController<PlaybackState>.broadcast();
  final _shuffleController = StreamController<bool>.broadcast();
  final _repeatController = StreamController<bool>.broadcast();
  final _positionController = StreamController<double>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _playbackQueueController = StreamController<List<(String, bool, int)>>.broadcast();
  final _previousQueueController = StreamController<List<String>>.broadcast();
  final _currentSongController = StreamController<SongData?>.broadcast();

  Stream<PlaybackState> get onPlaybackStateChanged => _playbackStateController.stream;
  Stream<bool> get onShuffleChanged => _shuffleController.stream;
  Stream<bool> get onRepeatChanged => _repeatController.stream;
  Stream<double> get onPositionChanged => _positionController.stream;
  Stream<double> get onVolumeChanged => _volumeController.stream;
  Stream<List<(String, bool, int)>> get onPlaybackQueueChanged => _playbackQueueController.stream;
  Stream<List<String>> get onPreviousQueueChanged => _previousQueueController.stream;
  Stream<SongData?> get onCurrentSongChanged => _currentSongController.stream;

  void init() {
    _player.positionStream.listen((pos) {
      _position = pos.inMilliseconds.toDouble() * 1000;
      _positionController.add(_position);
    });

    // on completion of current track
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        print("Track completed");
        next();
      }
    });
  }

  void toggle_play() {
    if (_currentSong == null) {
      print("No song loaded, cannot toggle playback");
      return;
    }

    if (_state == PlaybackState.playing) {
      _state = PlaybackState.paused;
      _player.pause();
    } else {
      _state = PlaybackState.playing;
      _player.play();
    }
    _playbackStateController.add(_state);
    print("Toggling playback: $_state");
  }

  void play() {
    _state = PlaybackState.playing;
    _player.play();
    _playbackStateController.add(_state);
    print("Playing");
  }

  void pause() {
    _state = PlaybackState.paused;
    _player.pause();
    _playbackStateController.add(_state);
    print("Pausing");
  }

  void stop() {
    _state = PlaybackState.paused;
    _player.pause();
    _playbackStateController.add(_state);
    _currentSong = null;
    _currentSongController.add(_currentSong?.$1);

    final queue = getPlaybackQueue();
    if (queue.isNotEmpty) {
      _previousQueue.add(queue.first.$1);
      _previousQueueController.add(_previousQueue);
    }

    _playlistQueue = [];
    _extraQueue = [];
    _playbackQueueController.add(getPlaybackQueue());

    print("Stopping");
  }

  void shuffle() {
    _shuffle = !_shuffle;
    _shuffleController.add(_shuffle);
    print("Toggling shuffle: $_shuffle");
  }

  void repeat() {
    _repeat = !_repeat;
    _repeatController.add(_repeat);
    print("Toggling repeat: $_repeat");
  }

  void next() {
    var queue = getPlaybackQueue();

    if (queue.isEmpty) {
      print("Queue is empty");
      return;
    }

    // Move current song to previous queue if it's from playlist
    if (_currentSong != null && _currentSong!.$2 == true) {
      _previousQueue.add(_currentSong!.$1.uuid);
      _previousQueueController.add(_previousQueue);
    }

    queue = getPlaybackQueue();
    if (queue.isEmpty) {
      _state = PlaybackState.stopped;
      _playbackStateController.add(_state);
      _currentSong = null;
      _currentSongController.add(_currentSong?.$1);
      print("No more songs in queue");
      return;
    }

    _playbackQueueController.add(getPlaybackQueue());
    loadIndex(0);
    play();
  }

  void previous() {
    // If progress is under 3 seconds, skip to previous song
    if (_position < 3e6) {
      if (_previousQueue.isEmpty) {
        print("No previous songs");
        return;
      }

      // Move current song back to playlist queue
      if (_currentSong != null && _currentSong!.$2 == true) {
        _playlistQueue.insert(0, _currentSong!.$1.uuid);
      }

      // Get previous song from previous queue
      String prevUuid = _previousQueue.removeLast();
      _previousQueueController.add(_previousQueue);

      _currentSong = null;
      _currentSongController.add(_currentSong?.$1);

      // Insert at beginning of playback queue
      _playlistQueue.insert(0, prevUuid);
      _playbackQueueController.add(getPlaybackQueue());

      loadIndex(0);
      play();
    } else {
      // If progress is over 3 seconds, seek to beginning
      seek(0);
      play();
    }
  }

  void loadIndex(int index) {
    var playbackQueue = getPlaybackQueue();

    if (playbackQueue.isEmpty) {
      print("Playback queue is empty");
      return;
    }

    print("Loading track at index: $index");

    var song = playbackQueue[index];
    var uuid = song.$1;
    print(uuid);
    StorageController().getSongFilePath(uuid).then((filePath) async {
      _player.setFilePath(filePath);

      _state = PlaybackState.playing;
      _playbackStateController.add(_state);

      _currentSong = (await UserController().getSongFromUUID(uuid), song.$2) as (SongData, bool)?;
      _currentSongController.add(_currentSong?.$1);

      // eat the songs from their list
      if (song.$2 == true) { // it's from the playlistqueue
        _playlistQueue.removeAt(song.$3);
      } else { // it's from extraqueue
        _extraQueue.removeAt(song.$3);
      }

      seek(0);
    });
  }


  void addQueue(SongData song) {
    _extraQueue.add(song.uuid);
    _playbackQueueController.add(getPlaybackQueue());

    if (getPlaybackQueue().length == 1) {
      loadIndex(0);
      play();
    }

    print("Adding song to extra queue: ${song.title}");
  }

  void seek(double position) {
    _position = position;
    _positionController.add(_position);

    _player.seek(Duration(milliseconds: (_position / 1000).round()));

    print("Seeking to position: $_position");
  }

  List<(String, bool, int)> getPlaybackQueue() {
    List<(String, bool, int)> list = [];
    for (int i = 0; i < _extraQueue.length; i++) {
      list.add((_extraQueue[i], false, i));
    }
    for (int i = 0; i < _playlistQueue.length; i++) {
      list.add((_playlistQueue[i], true, i));
    }
    return list;  // (String: uuid, bool: fromPlaylistQueue?)
  }

  void setPlaylist(PlaylistData playlist, SongData? startSong) {
    _playlistQueue = playlist.songs.map((song) => song.uuid).toList();
    _previousQueue = [];
    _previousQueueController.add(_previousQueue);

    if (startSong != null) {
      // move startSong to the front of the playlist queue
      _playlistQueue.remove(startSong.uuid);
      _playlistQueue.insert(0, startSong.uuid);
      loadIndex(0); // loadindex skal ta index 0 av playbackqueue i currentsong og fjerne fra køen sin
      play();
    }

    if (playlist.songs.isEmpty) {
      _playlistQueue = [];
    }

    _playbackQueueController.add(getPlaybackQueue());
    print(_extraQueue);
    print(_playlistQueue);

    print("Setting current playlist to: ${playlist.title}");
  }

  void volume(double vol) {
    _volume = vol;
    _volumeController.add(_volume);

    _player.setVolume(_volume);

    print("Setting volume to: $_volume");
  }

  void mute() {
    _muted = !_muted;
    if (_muted) {
      _player.setVolume(0.0);
    } else {
      _player.setVolume(_volume);
    }
    print("Toggling mute: $_muted");
  }

  void dispose() {
    _playbackStateController.close();
    _shuffleController.close();
    _repeatController.close();
    _positionController.close();
    _volumeController.close();
    _playbackQueueController.close();
    _player.dispose();
  }
}
import 'dart:async';

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
  SongData? _currentSong;

  PlaybackState get state => _state;
  bool get isShuffling => _shuffle;
  bool get isRepeating => _repeat;
  double get position => _position;
  double get currentVolume => _volume;
  bool get isMuted => _muted;
  List<String> get extraQueue => _extraQueue;
  List<String> get playlistQueue => _playlistQueue;
  List<String> get previousQueue => _previousQueue;
  SongData? get currentSong => _currentSong;

  final _playbackStateController = StreamController<PlaybackState>.broadcast();
  final _shuffleController = StreamController<bool>.broadcast();
  final _repeatController = StreamController<bool>.broadcast();
  final _positionController = StreamController<double>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _playbackQueueController = StreamController<List<String>>.broadcast();
  final _previousQueueController = StreamController<List<String>>.broadcast();
  final _currentSongController = StreamController<SongData?>.broadcast();

  Stream<PlaybackState> get onPlaybackStateChanged => _playbackStateController.stream;
  Stream<bool> get onShuffleChanged => _shuffleController.stream;
  Stream<bool> get onRepeatChanged => _repeatController.stream;
  Stream<double> get onPositionChanged => _positionController.stream;
  Stream<double> get onVolumeChanged => _volumeController.stream;
  Stream<List<String>> get onPlaybackQueueChanged => _playbackQueueController.stream;
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
    _currentSongController.add(_currentSong);
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
    print("Skipping to next track, before $_playlistQueue");
    if (_extraQueue.isNotEmpty) {
      // extraQueue is not added to previousQueue

      _extraQueue.removeAt(0);
      _playbackQueueController.add(getPlaybackQueue());

      loadCurrent();
      play();
    } else if (_playlistQueue.length > 1) {
      _previousQueue.add(getPlaybackQueue().first);
      _previousQueueController.add(_previousQueue);

      _playlistQueue.removeAt(0);
      _playbackQueueController.add(getPlaybackQueue());

      loadCurrent();
      play();
    } else if (_repeat) {
      throw UnimplementedError("Repeat functionality not implemented yet, repeat playlist from start");
    } else {
      stop();
      print("No more tracks in queue, stopping playback");
    }
    print("after $_playlistQueue");
  }

  void previous() {
    print("Skipping to previous track");
    if (_previousQueue.isNotEmpty) {
      var previousUUID = _previousQueue.removeLast();
      _previousQueueController.add(_previousQueue);

      // We know that all tracks put in previousQueue are from the playlistQueue so we add it back there
      //_playlistQueue.insert(0, getPlaybackQueue().first);
      //_playbackQueueController.add(getPlaybackQueue());

      _playlistQueue.insert(0, previousUUID);
      _playbackQueueController.add(getPlaybackQueue());

      loadCurrent();
      play();
    } else {
      seek(0);
      play();
    }
  }

  void seek(double position) {
    _position = position;
    _positionController.add(_position);

    _player.seek(Duration(milliseconds: (_position / 1000).round()));

    print("Seeking to position: $_position");
  }

  List<String> getPlaybackQueue() {
    return _extraQueue + (_playlistQueue ?? []);
  }

  void loadCurrent() {
    var uuid = getPlaybackQueue().first;

    StorageController().getSongFilePath(uuid).then((filePath) async {
      _player.setFilePath(filePath);

      _state = PlaybackState.playing;
      _playbackStateController.add(_state);

      _currentSong = await UserController().getSongFromUUID(uuid);
      _currentSongController.add(_currentSong);

      seek(0);
    });
  }
  
  void loadIndex(int index) {
    // remove all songs before index from extraQueue and playlistQueue, add to previousQueue
    var playbackQueue = getPlaybackQueue();
    for (int i = 0; i < index; i++) {
      _previousQueue.add(playbackQueue[i]);
    }
    _previousQueueController.add(_previousQueue);
    _extraQueue = playbackQueue.sublist(index).where((uuid) => !_playlistQueue!.contains(uuid)).toList();
    _playlistQueue = playbackQueue.sublist(index).where((uuid) => _playlistQueue!.contains(uuid)).toList();
    _playbackQueueController.add(getPlaybackQueue());
    print("Loading track at index: $index");

    var uuid = getPlaybackQueue().first;
    StorageController().getSongFilePath(uuid).then((filePath) async {
      _player.setFilePath(filePath);

      _state = PlaybackState.playing;
      _playbackStateController.add(_state);

      _currentSong = await UserController().getSongFromUUID(uuid);
      _currentSongController.add(_currentSong);

      seek(0);
    });
  }

  void addQueue(SongData song) {
    _extraQueue.add(song.uuid);
    _playbackQueueController.add(_extraQueue);

    print("Adding song to extra queue: ${song.title}");
  }

  void setPlaylist(PlaylistData playlist, SongData? startSong) {
    _playlistQueue = playlist.songs.map((song) => song.uuid).toList();

    if (startSong != null) {
      // move startSong to the front of the playlist queue
      _playlistQueue!.remove(startSong.uuid);
      _playlistQueue!.insert(0, startSong.uuid);
      loadCurrent();
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
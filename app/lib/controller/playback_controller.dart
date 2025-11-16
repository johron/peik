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
  List<String> _queue = [];
  List<String>? _playlistQueue;
  int _playbackIndex = 0;
  SongData? _currentSong;

  PlaybackState get state => _state;
  bool get isShuffling => _shuffle;
  bool get isRepeating => _repeat;
  double get position => _position;
  double get currentVolume => _volume;
  bool get isMuted => _muted;
  List<String> get queue => _queue;
  List<String>? get playlistQueue => _playlistQueue;
  int get playbackIndex => _playbackIndex;
  SongData? get currentSong => _currentSong;

  final _playbackStateController = StreamController<PlaybackState>.broadcast();
  final _shuffleController = StreamController<bool>.broadcast();
  final _repeatController = StreamController<bool>.broadcast();
  final _positionController = StreamController<double>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _queueController = StreamController<List<String>>.broadcast();
  final _playlistQueueController = StreamController<List<String>?>.broadcast();
  final _playbackIndexController = StreamController<int>.broadcast();

  Stream<PlaybackState> get onPlaybackStateChanged => _playbackStateController.stream;
  Stream<bool> get onShuffleChanged => _shuffleController.stream;
  Stream<bool> get onRepeatChanged => _repeatController.stream;
  Stream<double> get onPositionChanged => _positionController.stream;
  Stream<double> get onVolumeChanged => _volumeController.stream;
  Stream<List<String>> get onQueueChanged => _queueController.stream;
  Stream<List<String>?> get onCurrentPlaylistChanged => _playlistQueueController.stream;
  Stream<int> get onPlaybackIndexChanged => _playbackIndexController.stream;

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
    print("Skipping to next track");
    if (_playbackIndex < getPlaybackQueue().length - 1) {
      _playbackIndex++;
      _playbackIndexController.add(_playbackIndex);
      _loadSong();
      play();
    } else {
      if (_repeat) {
        _playbackIndex = 0;
        _playbackIndexController.add(_playbackIndex);
        _loadSong();
        play();
      } else {
        pause();
        seek(0);
        print("End of queue reached");
      }
    }
  }

  void previous() {
    print("Skipping to previous track");
    if (_playbackIndex > 0) {
      _playbackIndex--;
      _playbackIndexController.add(_playbackIndex);
      _loadSong();
      play();
    } else {
      seek(0);
    }
  }

  void seek(double position) {
    _position = position;
    _positionController.add(_position);

    _player.seek(Duration(milliseconds: (_position / 1000).round()));

    print("Seeking to position: $_position");
  }

  List<String> getPlaybackQueue() {
    return _queue + (playlistQueue ?? []);
  }

  void _loadSong() {
    var uuid = getPlaybackQueue()[_playbackIndex];
    StorageController().getSongFilePath(uuid).then((filePath) async {
      _player.setFilePath(filePath);

      _state = PlaybackState.playing;
      _playbackStateController.add(_state);

      _currentSong = await UserController().getSongFromUUID(uuid);

      seek(0);
    });
  }

  void addQueue(SongData song) {
    _queue.add(song.uuid);
    _queueController.add(_queue);

    if (getPlaybackQueue().length == 1) {
      _playbackIndex = 0;
      _loadSong();
    }

    print(_queue);
    print(_playlistQueue);
    print("Adding song to queue: ${song.title}");
  }

  void setPlaylist(PlaylistData playlist, SongData? startSong) {
    _playlistQueue = playlist.songs.map((song) => song.uuid).toList();

    if (startSong != null) {
      // move startSong to the front of the playlist queue
      _playlistQueue!.remove(startSong.uuid);
      _playlistQueue!.insert(0, startSong.uuid);
      _playbackIndex = 0;
      _loadSong();
      toggle_play();
    }

    if (playlist.songs.isEmpty) {
      _playlistQueue = null;
    }

    _playlistQueueController.add(_playlistQueue);
    print(_queue);
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
    _queueController.close();
    _playlistQueueController.close();
    _playbackIndexController.close();
    _player.dispose();
  }
}
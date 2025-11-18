
import 'package:flutter/material.dart';
import 'package:peik/component/floating_queue.dart';
import 'package:peik/component/rounded.dart';
import 'package:peik/controller/playback_controller.dart';
import 'package:peik/controller/user_controller.dart';
import 'package:peik/util/color.dart';
import 'package:peik/util/time.dart';
import 'package:peik/util/util.dart';

class Multimedia extends StatefulWidget {
  const Multimedia({super.key});

  @override
  State<Multimedia> createState() => _MultimediaState();
}

class _MultimediaState extends State<Multimedia> {
  final PlaybackController playbackController = PlaybackController();
  final UserController userController = UserController();

  OverlayEntry? _queueOverlay;
  bool _isQueueOpen = false;

  @override
  void initState() {
    super.initState();
    playbackController.onPlaybackStateChanged.listen((event) {
      updateState();
    });
    playbackController.onShuffleChanged.listen((event) {
      updateState();
    });
    playbackController.onRepeatChanged.listen((event) {
      updateState();
    });
    playbackController.onPositionChanged.listen((event) {
      updateState();
    });
    playbackController.onVolumeChanged.listen((event) {
      updateState();
    });
    playbackController.onPlaybackQueueChanged.listen((event) {
      updateState();
    });

    updateState();
  }

  void updateState() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var currentSong = playbackController.currentSong;
    return BottomAppBar(
      height: 100,
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: currentSong == null ? Container(
              alignment: Alignment.centerLeft,
              child: ListTile(
                leading: Rounded(child: Image.network(getMissingAlbumArtPath())),
              )) :
            Container(
              alignment: Alignment.centerLeft,
              child: ListTile(
                //leading: Rounded(child: Image.network(_controller.currentSong!.albumArtPath)),
                leading: Rounded(child: Image.network(getMissingAlbumArtPath())),
                title: Text(currentSong!.title, overflow: TextOverflow.ellipsis),
                subtitle: Text(currentSong!.artist, overflow: TextOverflow.ellipsis),
                trailing: IconButton(icon: Icon(Icons.favorite), onPressed: () {

                }),
              ),
            ),
          ),
          SizedBox(width: 500, child: Column(
            children: [
              Flex(
                mainAxisAlignment: MainAxisAlignment.center,
                direction: Axis.horizontal,
                children: [
                  IconButton(
                    icon: Icon(Icons.shuffle_rounded),
                    color: playbackController.isShuffling ? getToggledColor() : null,
                    onPressed: () {
                      if (currentSong == null) return;
                      playbackController.shuffle();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_previous_rounded),
                    onPressed: () {
                      if (currentSong == null) return;
                      playbackController.previous();
                    },
                  ),
                  IconButton(
                    icon: playbackController.state == PlaybackState.playing ? Icon(Icons.pause_rounded) : Icon(Icons.play_arrow_rounded),
                    onPressed: () {
                      if (currentSong == null) return;
                      print("before");
                      playbackController.toggle_play();
                      print("after");
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded),
                    onPressed: () {
                      if (currentSong == null) return;
                      playbackController.next();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.repeat_rounded),
                    color: playbackController.isRepeating ? getToggledColor() : null,
                    onPressed: () {
                      if (currentSong == null) return;
                      playbackController.repeat();
                    },
                  ),
                ]
              ),
              Expanded(child: Flex(
                mainAxisAlignment: MainAxisAlignment.center,
                direction: Axis.horizontal,
                spacing: 10,
                children: [
                  Text(formatDuration(Duration(milliseconds: (playbackController.position / 1000).round()))),
                  Expanded(child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: SliderComponentShape.noThumb,
                      overlayShape: SliderComponentShape.noThumb,
                    ),
                    child: Slider(
                      value: currentSong == null ? 0 : getSongDurationValue(playbackController.position, currentSong.duration.inMilliseconds * 1000),
                      onChanged: (value) {
                        if (currentSong == null) return;
                        playbackController.seek(multiplyDuration(currentSong.duration, value).inMilliseconds * 1000);
                      },
                    )
                  )),
                  //Text(formatDuration(_controller.currentSong == null ? Duration.zero : Duration(seconds: _controller.currentSong!.duration.inSeconds))),
                  Text(formatDuration(currentSong?.duration ?? Duration.zero)),
                ],
              )),
            ]
        )),
        Expanded(
          child: Container(
            alignment: Alignment.centerRight,
            child: Row(
              children: [
                Expanded(child: Container()),
                IconButton(
                  icon: Icon(Icons.mic_external_on_rounded),
                  onPressed: () {
                    updateState();
                  },
                ),IconButton(
                  icon: Icon(Icons.queue_music_rounded),
                  onPressed: () {
                    toggleQueue();
                  },
                ),
                IconButton(
                  icon: Icon(playbackController.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                  onPressed: () {
                    playbackController.mute();
                    updateState();
                  },
                ),
                Container(
                  width: 100,
                  margin: EdgeInsets.only(right: 15),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: SliderComponentShape.noThumb,
                      overlayShape: SliderComponentShape.noThumb,
                    ),
                    child: Slider(
                      value: playbackController.isMuted ? 0 : playbackController.currentVolume,
                      max: 1,
                      onChanged: (value) {
                          playbackController.volume(value);
                      },
                    )
                  )
                ),
              ],
            ),
          ),
        ),
      ]
    )
  );
  }

  OverlayEntry _createQueueOverlay() {
    return OverlayEntry(
      builder: (context) => Positioned(
        // adjust position/size as needed
        bottom: 105, // sits just above the BottomAppBar (app bar height was 100)
        right: 5,
        child: FloatingQueue(hideQueue: _hideQueue),
      ),
    );
  }

  void _showQueue() {
    if (_queueOverlay != null) return;
    _queueOverlay = _createQueueOverlay();
    Overlay.of(context)!.insert(_queueOverlay!);
    setState(() => _isQueueOpen = true);
  }

  void _hideQueue() {
    _queueOverlay?.remove();
    _queueOverlay = null;
    setState(() => _isQueueOpen = false);
  }

  void toggleQueue() {
    if (_isQueueOpen) _hideQueue(); else _showQueue();
  }
}
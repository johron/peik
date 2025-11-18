import 'package:flutter/material.dart';
import 'package:peik/component/rounded.dart';
import 'package:peik/view/multimedia.dart';

import '../controller/playback_controller.dart';
import '../controller/user_controller.dart';
import '../util/util.dart';

class FloatingQueue extends StatefulWidget {
  // callback to hideQueue
  final VoidCallback hideQueue;

  const FloatingQueue({super.key, required this.hideQueue});

  @override
  State<StatefulWidget> createState() => _FloatingQueueState();
}

class _FloatingQueueState extends State<FloatingQueue> {
  var playbackController = PlaybackController();
  var userController = UserController();

  @override
  void initState() {
    playbackController.onPlaybackQueueChanged.listen((event) {
      updateState();
    });
    playbackController.onPreviousQueueChanged.listen((event) {
      updateState();
    });
    playbackController.onCurrentSongChanged.listen((event) {
      updateState();
    });

    super.initState();
  }

  void updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Material build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {}, // absorb taps so overlay doesn't close on inner taps
        child: Card(
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 320,
            height: 460,
            padding: EdgeInsets.all(5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(width: 10),
                    Expanded(child: Text('Queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        widget.hideQueue();
                      },
                    )
                  ],
                ),
                Divider(),
                // Prototype content: replace with real queue UI
                Expanded(
                  child: Column(
                    children: [
                      Text("Currently Playing"),
                      ListTile(
                        leading: Rounded(child: Image.network(
                          getMissingAlbumArtPath(), width: 40,
                          height: 40,
                          fit: BoxFit.cover
                        )),
                        title: Text(
                          playbackController.currentSong?.title ?? "No song playing",
                          overflow: TextOverflow.ellipsis
                        ),
                        subtitle: Text(
                          playbackController.currentSong?.artist ?? "",
                          overflow: TextOverflow.ellipsis
                        ),
                      ),
                      Divider(),
                      Text("Up Next"),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: playbackController.extraQueue.length,
                        itemBuilder: (context, index) {
                          if (playbackController.extraQueue.isEmpty) {
                            return SizedBox.shrink();
                          }

                          var uuid = playbackController.extraQueue[index];
                          return FutureBuilder(
                            future: UserController().getSongFromUUID(uuid),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const CircularProgressIndicator();
                              } else if (snapshot.hasError) {
                                return Text("Error loading playlist: ${snapshot.error}");
                              } else {
                                var song = snapshot.data!;
                                return ListTile(
                                  leading: Rounded(child: Image.network(
                                    getMissingAlbumArtPath(), width: 40,
                                    height: 40,
                                    fit: BoxFit.cover
                                  )),
                                  title: Text(song.title, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(song.artist, overflow: TextOverflow.ellipsis),
                                  onTap: () {
                                    playbackController.loadIndex(index);
                                  },
                                );
                              }
                            }
                          );
                        },
                      ),
                      Divider(),
                      Text("Playlist"),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: playbackController.playlistQueue == null ? 0 : playbackController.playlistQueue!.length,
                        itemBuilder: (context, index) {
                          if (playbackController.playlistQueue == null) {
                            return SizedBox.shrink();
                          }
                          var uuid = playbackController.playlistQueue![index];
                          return FutureBuilder(
                              future: UserController().getSongFromUUID(uuid),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                } else if (snapshot.hasError) {
                                  return Text("Error loading playlist: ${snapshot.error}");
                                } else {
                                  var song = snapshot.data!;
                                  return ListTile(
                                    leading: Rounded(child: Image.network(
                                        getMissingAlbumArtPath(), width: 40,
                                        height: 40,
                                        fit: BoxFit.cover
                                    )),
                                    title: Text(song.title, overflow: TextOverflow.ellipsis),
                                    subtitle: Text(song.artist, overflow: TextOverflow.ellipsis),
                                    onTap: () {
                                      playbackController.loadIndex(index);
                                    },
                                  );
                                }
                              }
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> getPlaybackQueue() {
    var playbackQueue = playbackController.getPlaybackQueue();
    if (playbackQueue.isNotEmpty) {
      playbackQueue = playbackQueue.sublist(1); // exclude current song
    }
    return playbackQueue;
  }
}
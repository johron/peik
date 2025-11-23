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
                Expanded(
                  child: FutureBuilder<List<Widget>>(
                    future: generateQueueElements(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text("Error loading queue"));
                      } else {
                        var elements = snapshot.data ?? [];
                        return ListView(
                          children: elements,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<Widget>> generateQueueElements() async {
    List<Widget> elements = [];
    var extraQueue = playbackController.extraQueue;
    var playlistQueue = playbackController.playlistQueue;
    var currentSong = playbackController.currentSong;

    elements.add(Row(
      children: [
        SizedBox(width: 10),
        Text("Now Playing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    ));
    elements.add(
      ListTile(
        leading: Rounded(child: Image.network(
            getMissingAlbumArtPath(), width: 40,
            height: 40,
            fit: BoxFit.cover
        )),
        title: Text(
            currentSong?.title ?? "No song playing",
            overflow: TextOverflow.ellipsis
        ),
        subtitle: Text(
            currentSong?.artist ?? "",
            overflow: TextOverflow.ellipsis
        ),
      )
    );

    if (extraQueue.isNotEmpty) {
      elements.add(Divider());
      elements.add(Text("Up Next"));
      for (var i = 0; i < extraQueue.length; i++) {
        var uuid = extraQueue[i];
        var song = await userController.getSongFromUUID(uuid);
        if (song == null) continue;
        elements.add(
          ListTile(
            leading: Rounded(child: Image.network(
              getMissingAlbumArtPath(), width: 40,
              height: 40,
              fit: BoxFit.cover
            )),
            title: Text(song.title, overflow: TextOverflow.ellipsis),
            subtitle: Text(song.artist, overflow: TextOverflow.ellipsis),
            onTap: () {
              playbackController.loadIndex(i);
            },
          )
        );
      }
    }

    if (playlistQueue.isNotEmpty) {
      elements.add(Divider());
      elements.add(Text("Playlist"));
      for (var i = 0; i < playlistQueue.length; i++) {
        var uuid = playlistQueue[i];
        var song = await userController.getSongFromUUID(uuid);
        if (song == null) continue;
        elements.add(
          ListTile(
            leading: Rounded(child: Image.network(
              getMissingAlbumArtPath(), width: 40,
              height: 40,
              fit: BoxFit.cover
            )),
            title: Text(song.title, overflow: TextOverflow.ellipsis),
            subtitle: Text(song.artist, overflow: TextOverflow.ellipsis),
            onTap: () {
              playbackController.loadIndex(i);
            },
          )
        );
      }
    }

    if (playbackController.previousQueue.isNotEmpty) {
      elements.add(Divider());
      elements.add(Row(
        children: [
          SizedBox(width: 10),
          Text("Previously Played", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ));
      for (var i = playbackController.previousQueue.length - 1; i >= 0; i--) {
        var uuid = playbackController.previousQueue[i];
        var song = await userController.getSongFromUUID(uuid);
        if (song == null) continue;
        elements.add(
          ListTile(
            leading: Rounded(child: Image.network(
              getMissingAlbumArtPath(), width: 40,
              height: 40,
              fit: BoxFit.cover
            )),
            title: Text(song.title, overflow: TextOverflow.ellipsis),
            subtitle: Text(song.artist, overflow: TextOverflow.ellipsis),
            onTap: () {

            },
          )
        );
      }
    }

    return elements;
  }
}
import 'package:flutter/material.dart';
import 'package:peik/component/index_and_play.dart';
import 'package:peik/component/rounded.dart';
import 'package:peik/component/snackbar.dart';
import 'package:peik/controller/playback_controller.dart';
import 'package:peik/controller/user_controller.dart';
import 'package:peik/util/util.dart';

import '../controller/storage_controller.dart';
import '../type/playlist_data.dart';
import '../type/song_data.dart';
import '../util/color.dart';
import '../util/time.dart';

class PlaylistPage extends StatefulWidget {
  final String uuid;

  const PlaylistPage({
    required this.uuid,
    super.key
  });

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final userController = UserController();
  final storageController = StorageController();
  final playbackController = PlaybackController();

  void updateState() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    userController.onUserUpdated.listen((event) {
      updateState();
    });

    if (widget.uuid == "all_songs") {
      storageController.onSongAdded.listen((event) {
        updateState();
      });
      storageController.onSongRemoved.listen((event) {
        updateState();
      });
    }

    playbackController.onShuffleChanged.listen((event) {
      updateState();
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          FutureBuilder<PlaylistData>(
            future: getPlaylist(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text("Error loading playlist: ${snapshot.error}");
              } else {
                var playlist = snapshot.data!;
                return Row(
                  children: [
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: Rounded(
                        radius: 8,
                        child: Image.network(getMissingAlbumArtPath()),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _generateSubtitle(playlist),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        )
                      ]
                    ),
                    Expanded(child: Container()),
                    FutureBuilder<List<String>>(
                      future: userController.getPinnedPlaylists(),
                      builder: (context, snapshot) {
                        final pinned = snapshot.data ?? [];
                        final isPinned = pinned.contains(playlist.uuid);
                        return IconButton(
                          icon: Icon(Icons.push_pin_rounded, size: 30, color: isPinned ? getToggledColor() : Colors.white70),
                          onPressed: () async {
                            if (isPinned) {
                              await userController.unpinPlaylist(playlist.uuid);
                            } else {
                              await userController.pinPlaylist(playlist.uuid);
                            }
                            updateState();
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.shuffle_rounded, size: 30, color: playbackController.isShuffling ? getToggledColor() : Colors.white70),
                      onPressed: () {
                        playbackController.shuffle();
                      },
                    ),
                    IconButton(icon: Icon(Icons.play_circle_rounded, size: 64, color: getToggledColor()), onPressed: () {
                      playbackController.setPlaylist(playlist, null);
                    }),
                  ],
                );
              }
            },
          ),
          SizedBox(height: 12),
          Expanded(
            // sortable, scrollable, resizable list of songs in the playlist, like spotify's
            child: FutureBuilder<PlaylistData>(
              future: getPlaylist(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text("Error loading playlist: ${snapshot.error}");
                } else {
                  var playlist = snapshot.data!;
                  return ListView(
                    shrinkWrap: true,
                    children: [DataTable(
                      columns: [
                        DataColumn(label: Container(
                          width: 90,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(width: 17),
                              Text('#'),
                              SizedBox(width: 25),
                              Text("Title"),
                            ],
                          ),
                        ), columnWidth: FixedColumnWidth(300)),
                        DataColumn(label: Text('Album', style: TextStyle(color: Colors.white70)), columnWidth: FixedColumnWidth(200)),
                        DataColumn(label: Text('Date Added', style: TextStyle(color: Colors.white70)), columnWidth: FixedColumnWidth(150)),
                        DataColumn(label: Icon(Icons.access_time, color: Colors.white70, size: 20), columnWidth: FixedColumnWidth(75)),
                      ],
                      rows: _buildSongRows(playlist)
                    )]
                  );
                }
              },
            ),
          ),
        ],
      )
    );
  }

  List<DataRow> _buildSongRows(PlaylistData playlist) {
    List<DataRow> rows = [];
    for (SongData song in playlist.songs) {
      rows.add(DataRow(
        cells: [
          gestureCell(
            Row(
              children: [
                Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: IndexAndPlay(
                        index: playlist.songs.indexOf(song),
                        onPlay: () {
                          print("Play song: ${song.title}");
                          playbackController.setPlaylist(playlist, song);
                        }
                    )
                ),
                SizedBox(width: 10),
                Rounded(
                  radius: 5,
                  child: Image.network(
                    getMissingAlbumArtPath(),
                    //data.albumArtPath,
                    width: 35,
                    height: 35,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ), song
          ),
          gestureCell(Text(song.album, overflow: TextOverflow.ellipsis), song),
          gestureCell(Text(formatDateTime(song.added), overflow: TextOverflow.ellipsis), song),
          gestureCell(Text(formatDuration(song.duration), overflow: TextOverflow.ellipsis), song),
        ],
      ));
    }

    return rows;
  }

  DataCell gestureCell(Widget child, SongData song) {
    return DataCell(
      GestureDetector(
        onSecondaryTapDown: (details) async {
          final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
          final selected = await showMenu<String>(
            context: context,
            position: RelativeRect.fromRect(
              details.globalPosition & const Size(1, 1),
              Offset.zero & overlay.size,
            ),
            items: const [
              PopupMenuItem(value: 'add', child: Text('Add to playlist')),
              PopupMenuItem(value: 'remove', child: Text('Remove from playlist')),
              PopupMenuItem(value: 'queue', child: Text('Add to queue')),
              PopupMenuItem(value: 'edit', child: Text('Edit')),
            ],
          );
          if (selected == 'add') {
            print('Add song to playlist: ${song.title}');
            // Add a branch populated with user's playlists to choose from
            final user = await userController.user;
            final playlistItems = user.playlists.map((p) => PopupMenuItem<String>(
              value: p.uuid,
              child: Text(p.title),
            )).toList();

            final target = await showMenu<String>(
              context: context,
              position: RelativeRect.fromRect(
                details.globalPosition & const Size(1, 1),
                Offset.zero & overlay.size,
              ),
              items: playlistItems,
            );

            if (target != null) {
              print("Add '${song.title}' to playlist: $target");
              OSnackBar(message: "Added '${song.title}' to playlist").show(context);
              userController.addSongToPlaylist(song.uuid, target);
            }
          } else if (selected == 'queue') {
            PlaybackController().addQueue(song);
          } else if (selected == 'edit') {
            print('Edit song: ${song.title}');
          } else if (selected == 'remove') {
            UserController().removeSongFromPlaylist(song.uuid, widget.uuid);
            if (widget.uuid == "all_songs") { {
              // Show a confirmation dialog before deleting the song from storage
              StorageController().removeSong(song.uuid).then((success) {
                if (!success) {
                  OSnackBar(message: "Failed to delete song '${song.title}'").show(context);
                }
              });
            }}
          }
        },
        child: child,
      ),
    );
  }

  Future<PlaylistData> getPlaylist() async {
    if (widget.uuid != "all_songs") {
      var user = await userController.user;

      return user.playlists.firstWhere((playlist) => playlist.uuid == widget.uuid);
    } else {
      var stream = await storageController.loadStream();
      if (stream == null) {
        throw Exception("Stream is null");
      }

      var songs = stream.songs;

      return PlaylistData(
        uuid: widget.uuid,
        title: "All Songs",
        songs: songs,
        created: DateTime.now(),
        lastUpdate: DateTime.now(),
      );
    }
  }
  
  String _generateSubtitle(PlaylistData playlist) {
    var subtitle = "";
    if (playlist.description != null && playlist.description != "") {
      subtitle += "${playlist.description!} · ";
    }
    if (playlist.songs.isEmpty) {
      subtitle += "No songs";
      return subtitle;
    }
    subtitle += playlist.songs.length == 1 ? "${playlist.songs.length} song" : "${playlist.songs.length} songs";

    var totalDuration = playlist.songs.fold<Duration>(Duration.zero, (previousValue, song) => previousValue + song.duration);
    int days = totalDuration.inDays;
    int hours = totalDuration.inHours % 24;
    int minutes = totalDuration.inMinutes % 60;
    String durationStr;

    if (days > 0) {
      durationStr = days == 1 ? "1 day" : "$days days";
      if (hours > 0) durationStr += " ${hours == 1 ? '1 hr' : '$hours hrs'}";
    } else if (hours > 0) {
      durationStr = hours == 1 ? "1 hr" : "$hours hrs";
      if (minutes > 0) durationStr += " ${minutes == 1 ? '1 min' : '$minutes mins'}";
    } else {
      durationStr = minutes == 1 ? "1 min" : "$minutes mins";
    }
    subtitle += " · $durationStr";

    return subtitle;
  }
}
import 'package:flutter/material.dart';
import 'package:peik/component/dialog/playlist_create_dialog.dart';
import 'package:peik/component/gesture/playlist.dart';
import 'package:peik/controller/user_controller.dart';
import 'package:peik/type/page.dart';
import 'package:peik/util/util.dart';

import '../component/rounded.dart';
import '../controller/auth_controller.dart';
import '../type/playlist_data.dart';

class Sidebar extends StatefulWidget {
  final ValueChanged<OPage>? onPageSelected;
  final OPage initialPage;

  const Sidebar({
    super.key,
    this.onPageSelected,
    this.initialPage = const OPage(Pages.library, null),
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  late OPage selectedPage;

  final AuthController auth = AuthController();
  final UserController user = UserController();

  @override
  void initState() {
    super.initState();
    selectedPage = widget.initialPage;

    auth.onAuthenticatedStream.listen((event) {
      updateState();
    });

    user.onUserUpdated.listen((event) {
      updateState();
    });

    user.onUserSelectedPage.listen((page) {
      selectedPage = page;
      updateState();
    });
  }

  void updateState() {
    setState(() {});
  }

  void _changePage(OPage page) {
    if (selectedPage.uuid == page.uuid && selectedPage.page == page.page) {
      return;
    }

    selectedPage = page;
    widget.onPageSelected?.call(selectedPage);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Color(0x0AFFFFFF),
      padding: const EdgeInsets.only(left: 5, top: 10, right: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.library_music),
            title: Text('Library'),
            selected: selectedPage.page == Pages.library,
            onTap: () => _changePage(OPage(Pages.library, null)),
            trailing: IconButton(icon: Icon(Icons.playlist_add), onPressed: () {
              // Show dialog to create new playlist
              carefulShowDialog(context: context, builder: (context) {
                return PlaylistCreateDialog();
              });
            }),
          ),
          ListTile(
            leading: Icon(Icons.search),
            title: Text('Search'),
            selected: selectedPage.page == Pages.search,
            onTap: () => _changePage(OPage(Pages.search, null)),
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            selected: selectedPage.page == Pages.settings,
            onTap: () => _changePage(OPage(Pages.settings, null)),
          ),
          Divider(color: Colors.grey[700]),
          Expanded(
            child: FutureBuilder(future: getPlaylists(), builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error loading playlists'));
              } else {
                var playlists = snapshot.data as List<Playlist>;
                if (playlists.isEmpty) {
                  return Center(child: Text('No pinned playlists'));
                }

                return ListView(
                  children: playlists,
                );
              }
            }),
          ),
        ],
      ),
    );
  }

  Future<List<Playlist>> getPlaylists() async {
    if (auth.loggedInUser == null) {
      return [];
    }

    if (!auth.loggedInUser!.isAuthenticated) {
      return [];
    }

    var pinnedPlaylists= await UserController().getPinnedPlaylists();

    List<Playlist> playlists = [];
    for (var uuid in pinnedPlaylists) {
      var playlist = await UserController().getPlaylistByUUID(uuid);

      if (uuid == "all_songs") {
        playlist = PlaylistData(
          uuid: "all_songs",
          title: "All Songs",
          songs: [],
          created: DateTime.now(),
          lastUpdate: DateTime.now(),
        );
      }

      if (playlist == null) {
        continue;
      }

      playlists.add(
        Playlist(playlist: playlist, widget: ListTile(
          leading: Rounded(child: Image.network(getMissingAlbumArtPath(), scale: 5)),
          title: Text(playlist.title, overflow: TextOverflow.ellipsis),
          selected: selectedPage.page == Pages.playlist && selectedPage.uuid == uuid,
          onTap: () => _changePage(OPage(Pages.playlist, uuid)),
        ))
      );
    }
    return playlists;
}
}
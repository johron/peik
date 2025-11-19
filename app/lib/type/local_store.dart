class LocalStore {
  final String loggedInUser;
  final List<String> pinnedPlaylists; // of uuids

  LocalStore({
    required this.loggedInUser,
    required this.pinnedPlaylists,
  });

  Map<String, dynamic> toJson() {
    return {
      'loggedInUser': loggedInUser,
      'pinnedPlaylists': pinnedPlaylists,
    };
  }

  factory LocalStore.fromJson(Map<String, dynamic> json) {
    return LocalStore(
      loggedInUser: json['loggedInUser'],
      pinnedPlaylists: List<String>.from(json['pinnedPlaylists'] ?? []),
    );
  }
}
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:peik/controller/storage_controller.dart';
import 'package:peik/controller/user_controller.dart';
import 'package:peik/type/configuration_data.dart';
import 'package:peik/type/local_store.dart';
import 'package:peik/type/user_data.dart';

class AuthUser {
  final UserData user;
  final bool isAuthenticated;

  AuthUser({
    required this.user,
    required this.isAuthenticated,
  });
}

class AuthController {
  AuthController._internal();

  static final AuthController _instance = AuthController._internal();

  factory AuthController() => _instance;

  AuthUser? _loggedInUser;

  AuthUser? get loggedInUser => _loggedInUser;

  final _authenticatedStateController = StreamController<AuthUser?>.broadcast();

  Stream<AuthUser?> get onAuthenticatedStream => _authenticatedStateController.stream;

  Future<void> init() async {
    var storage = StorageController();
    var userController = UserController();

    userController.onUserUpdated.listen((userData) {
      _loggedInUser = AuthUser(user: userData,
          isAuthenticated: _loggedInUser?.isAuthenticated ?? false);
    });

    var localStore = await storage.loadLocalStore();
    if (localStore == null) {
      return;
    }

    var username = localStore.loggedInUser;
    await login(username);
  }

  String hashSha256(String input) {
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  String? generateToken() {
    var storage = StorageController();

    storage.loadStream().then((data) {
      if (data == null) {
        return null;
      }

      if (data.token != "") {
        return null;
      }
    });

    var tokenBytes = List<int>.generate(16, (i) => i + DateTime.now().millisecondsSinceEpoch % 256);
    var token = base64Url.encode(tokenBytes);

    return token;
  }

  Future<bool> signup(String username, String? pin) async {
    var storage = StorageController();

    var stream = await storage.loadStream();
    if (stream == null) {
      return false;
    }

    for (var user in stream.users) {
      if (user.username == username) {
        return false;
      }
    }

    var newUser = UserData(
      username: username,
      playlists: [],
      configuration: ConfigurationData(),
      pin: pin != null ? hashSha256(pin) : null,
    );

    await storage.addUser(newUser);

    await login(username);

    return true;
  }

  Future<bool> login(String username) async {
    var storage = StorageController();
    var stream = await storage.loadStream();

    if (stream == null) {
      print("No stream data available for login.");
      return false;
    }

    for (var user in stream.users) {
      if (user.username == username) {
        if (user.pin != null) {
          _loggedInUser = AuthUser(user: user, isAuthenticated: false);
        } else {
          _loggedInUser = AuthUser(user: user, isAuthenticated: true);
        }

        print("User ${user.username} logged in successfully.");

        _authenticatedStateController.add(_loggedInUser);
        var localStore = await storage.loadLocalStore();

        await storage.saveLocalStore(LocalStore(loggedInUser: _loggedInUser!.user.username, pinnedPlaylists: localStore?.pinnedPlaylists ?? []));

        return true;
      }
    }

    print("Login failed for user $username.");
    return false;
  }

  bool verifyPin(String pin) {
    if (_loggedInUser == null) {
      return false;
    }

    var hashedPin = hashSha256(pin);

    if (_loggedInUser!.user.pin == hashedPin) {
      _loggedInUser = AuthUser(user: _loggedInUser!.user, isAuthenticated: true);

      _authenticatedStateController.add(_loggedInUser);

      return true;
    } else {
      return false;
    }
  }

  bool logout() {
    if (_loggedInUser != null) {
      _loggedInUser = null;

      _authenticatedStateController.add(_loggedInUser);

      return true;
    } else {
      return false;
    }
  }
}
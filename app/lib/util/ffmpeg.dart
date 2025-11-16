import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:process_run/process_run.dart';

Future<Duration> getDuration(String path) async {
  var duration = Duration.zero;
  if (Platform.isWindows || Platform.isLinux) {
    var shell = Shell();
    await shell.run('''
        ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$path"
      ''').then((result) {
      if (result.isNotEmpty) {
        var durationStr = result.outText.trim();
        var durationSeconds = double.tryParse(durationStr);
        if (durationSeconds != null) {
          duration = Duration(seconds: durationSeconds.toInt());
        }
      }
    });
  } else if (Platform.isMacOS || Platform.isIOS || Platform.isAndroid) { // use ffmpeg_kit_flutter_new
    FFprobeKit.getMediaInformation(path).then((info) {
      var mediaInfo = info.getMediaInformation();
      if (mediaInfo != null) {
        var durationStr = mediaInfo.getDuration();
        if (durationStr != null) {
          var durationSeconds = double.tryParse(durationStr);
          if (durationSeconds != null) {
            duration = Duration(seconds: durationSeconds.toInt());
          }
        }
      }
    });
  } else {
    throw Exception("Unsupported platform for getting media duration");
  }

  return duration;
}

Future<bool> convertToFlac(String inputPath) async {
  var outputPath = inputPath.replaceAll(RegExp(r'\.[^.]+$'), '.flac');

  if (Platform.isWindows || Platform.isLinux) {
    var shell = Shell();
    await shell.run('''
        ffmpeg -i "$inputPath" -c:a flac "$outputPath"
      ''');
  } else if (Platform.isMacOS || Platform.isIOS || Platform.isAndroid) { // use ffmpeg_kit_flutter_new
    await FFmpegKit.execute('-i "$inputPath" -c:a flac "$outputPath"');
  } else {
    throw Exception("Unsupported platform for converting to FLAC");
  }

  return true;
}
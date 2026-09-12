import 'dart:io';
import 'package:flutter/foundation.dart';

class FileLauncher {
  FileLauncher._();

  /// Opens the file at [filePath] in the operating system's default viewer/application.
  /// Returns true if the process was launched successfully.
  static Future<bool> openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('FileLauncher: file does not exist at $filePath');
        return false;
      }

      if (Platform.isWindows) {
        // cmd /c start "" "filePath" launches the associated application for any extension
        final result = await Process.run('cmd', ['/c', 'start', '', filePath]);
        return result.exitCode == 0;
      } else if (Platform.isMacOS) {
        final result = await Process.run('open', [filePath]);
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [filePath]);
        return result.exitCode == 0;
      } else {
        debugPrint('FileLauncher: unsupported platform for direct shell launch');
        return false;
      }
    } catch (e) {
      debugPrint('FileLauncher: error opening file: $e');
      return false;
    }
  }
}

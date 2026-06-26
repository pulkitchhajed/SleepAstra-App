import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformFileReader {
  static Future<Uint8List?> readAsBytes(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[PlatformFileReader] Deleted file: $path');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[PlatformFileReader] Error deleting file: $e');
      return false;
    }
  }
}

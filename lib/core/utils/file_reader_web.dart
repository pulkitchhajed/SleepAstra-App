import 'dart:typed_data';

class PlatformFileReader {
  static Future<Uint8List?> readAsBytes(String path) async {
    // On Web, we usually fetch from a blob URL or use another method.
    // The screen logic already handles this via http.get(Uri.parse(path)).
    // This is here to satisfy the conditional import.
    return null; 
  }

  static Future<bool> deleteFile(String path) async {
    return true; // No-op on web
  }
}

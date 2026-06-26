import 'dart:typed_data';

abstract class PlatformFileReader {
  static Future<Uint8List?> readAsBytes(String path) {
    throw UnsupportedError('Cannot read file without platform implementation.');
  }

  static Future<bool> deleteFile(String path) {
    throw UnsupportedError('Cannot delete file without platform implementation.');
  }
}

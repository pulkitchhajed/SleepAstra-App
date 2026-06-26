import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Levels for log entries.
enum LogLevel { info, warning, error }

/// A persistent, file-based logger for sleep recording & analysis events.
///
/// Writes timestamped entries to `<documents>/snore_recording.log`.
/// The log file rolls over (is cleared) once it exceeds 2 MB to prevent
/// unbounded growth over many nights of recording.
class RecordingLogger {
  static const _fileName = 'snore_recording.log';
  static const _maxFileSizeBytes = 2 * 1024 * 1024; // 2 MB

  static RecordingLogger? _instance;
  File? _logFile;
  bool _initialised = false;

  RecordingLogger._();
  factory RecordingLogger() => _instance ??= RecordingLogger._();

  // ── Initialisation ──────────────────────────────────────────────

  Future<void> _ensureInit() async {
    if (_initialised) return;
    if (kIsWeb) { _initialised = true; return; }
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/$_fileName');

      // Roll over if too large
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size > _maxFileSizeBytes) {
          await _logFile!.writeAsString(
            '=== Log rolled over at ${DateTime.now().toIso8601String()} (file exceeded 2 MB) ===\n',
          );
        }
      }
      _initialised = true;
    } catch (e) {
      debugPrint('[RecordingLogger] init error: $e');
    }
  }

  // ── Public API ──────────────────────────────────────────────────

  Future<void> info(String message)    => _write(LogLevel.info,    message);
  Future<void> warning(String message) => _write(LogLevel.warning, message);
  Future<void> error(String message, [Object? exception, StackTrace? stack]) async {
    final detail = exception != null ? '\n  exception: $exception' : '';
    final trace  = stack    != null ? '\n  stacktrace:\n${stack.toString().split('\n').take(8).join('\n')}' : '';
    await _write(LogLevel.error, '$message$detail$trace');
  }

  /// Returns the full log content as a String (for display / share).
  Future<String> readLog() async {
    await _ensureInit();
    if (kIsWeb || _logFile == null) return 'Logging not supported on this platform.';
    try {
      if (!await _logFile!.exists()) return 'No log file found yet.';
      return await _logFile!.readAsString();
    } catch (e) {
      return 'Error reading log: $e';
    }
  }

  /// Clears the log file.
  Future<void> clearLog() async {
    await _ensureInit();
    if (kIsWeb || _logFile == null) return;
    try {
      await _logFile!.writeAsString('=== Log cleared at ${DateTime.now().toIso8601String()} ===\n');
    } catch (e) {
      debugPrint('[RecordingLogger] clearLog error: $e');
    }
  }

  /// Returns the absolute path to the log file.
  Future<String?> get logFilePath async {
    await _ensureInit();
    return _logFile?.path;
  }

  // ── Internal ────────────────────────────────────────────────────

  Future<void> _write(LogLevel level, String message) async {
    await _ensureInit();
    final ts    = DateTime.now().toIso8601String();
    final tag   = level.name.toUpperCase().padRight(7);
    final entry = '[$ts] [$tag] $message\n';

    // Always mirror to Flutter console
    debugPrint('[RecordingLogger] $entry');

    if (kIsWeb || _logFile == null) return;
    try {
      await _logFile!.writeAsString(entry, mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('[RecordingLogger] write error: $e');
    }
  }
}

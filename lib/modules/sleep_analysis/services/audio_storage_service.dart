import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/recording_logger.dart';
import '../models/sleep_report.dart';

class AudioStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a single snore audio clip to Firebase Storage.
  static Future<String?> uploadSnoreAudio(String uid, String localFilePath, DateTime recordedAt, int index) async {
    try {
      final file = File(localFilePath);
      if (!file.existsSync()) return null;

      final fileName = 'snore_${recordedAt.millisecondsSinceEpoch}_$index.wav';
      final ref = _storage.ref().child('users/$uid/snore_audio/$fileName');

      final metadata = SettableMetadata(
        contentType: 'audio/wav',
        customMetadata: {
          'recordedAt': recordedAt.toIso8601String(),
        },
      );

      final uploadTask = await ref.putFile(file, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      RecordingLogger().error('Failed to upload snore audio', e);
      return null;
    }
  }

  /// Uploads a list of snore audio clips to Firebase Storage.
  /// Returns a new list of clips with the `remoteUrl` populated.
  static Future<List<SnoreAudioClip>> uploadSnoreAudioClips(String uid, List<SnoreAudioClip> clips, DateTime recordedAt) async {
    RecordingLogger().info('Uploading ${clips.length} snore audio clips to Firebase Storage...');
    
    // Force token refresh since the recording might have taken 8+ hours (token expires in 1h)
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (e) {
      RecordingLogger().error('Failed to refresh auth token before upload', e);
    }

    final updatedClips = <SnoreAudioClip>[];
    
    // Upload in chunks of 5 to avoid overwhelming the network/Firebase
    const chunkSize = 5;
    for (int i = 0; i < clips.length; i += chunkSize) {
      final end = (i + chunkSize < clips.length) ? i + chunkSize : clips.length;
      final chunk = clips.sublist(i, end);
      
      final uploadTasks = <Future<SnoreAudioClip>>[];
      for (int j = 0; j < chunk.length; j++) {
        final clip = chunk[j];
        final actualIndex = i + j;
        uploadTasks.add(() async {
          final url = await uploadSnoreAudio(uid, clip.localPath, recordedAt, actualIndex);
          return SnoreAudioClip(
            timestamp: clip.timestamp,
            duration: clip.duration,
            localPath: clip.localPath,
            remoteUrl: url,
          );
        }());
      }
      
      final completedChunk = await Future.wait(uploadTasks);
      updatedClips.addAll(completedChunk);
    }
    
    RecordingLogger().info('Finished uploading snore audio clips.');
    return updatedClips;
  }

  /// Deletes a snore audio file from Firebase Storage.
  static Future<void> deleteSnoreAudio(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      RecordingLogger().info('Deleted snore audio from Firebase Storage: $url');
    } catch (e) {
      RecordingLogger().error('Failed to delete snore audio from Firebase Storage', e);
    }
  }
}

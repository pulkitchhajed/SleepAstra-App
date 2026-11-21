import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/audio_track_model.dart';
import '../../admin/services/admin_log_service.dart';

class AudioTrackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<AudioTrackModel>> getAudioTracks() {
    return _firestore
        .collection('audio_tracks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AudioTrackModel.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<void> addAudioTrack(AudioTrackModel track) async {
    if (track.id.isNotEmpty) {
      await _firestore.collection('audio_tracks').doc(track.id).set(track.toJson());
    } else {
      await _firestore.collection('audio_tracks').add(track.toJson());
    }
    await AdminLogService.logActivity(
      action: 'Audio Track Added',
      details: 'Added audio track: "${track.title}" (${track.category})',
    );
  }

  Future<void> updateAudioTrack(AudioTrackModel track) async {
    await _firestore.collection('audio_tracks').doc(track.id).set(track.toJson(), SetOptions(merge: true));
    await AdminLogService.logActivity(
      action: 'Audio Track Updated',
      details: 'Updated audio track: "${track.title}" (ID: ${track.id})',
    );
  }

  Future<void> deleteAudioTrack(String id) async {
    await _firestore.collection('audio_tracks').doc(id).delete();
    await AdminLogService.logActivity(
      action: 'Audio Track Deleted',
      details: 'Deleted audio track ID: $id',
    );
  }
}

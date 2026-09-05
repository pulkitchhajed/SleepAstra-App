import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import 'package:uuid/uuid.dart';
import '../../audio/models/audio_track_model.dart';
import '../../audio/services/audio_track_service.dart';
import '../../videos/services/video_service.dart';
import '../models/wellness_zone_model.dart';
import '../services/wellness_zone_service.dart';

class UploadAudioScreen extends StatefulWidget {
  final AudioTrackModel? existingAudio;
  final String? defaultCategory;
  const UploadAudioScreen({super.key, this.existingAudio, this.defaultCategory});

  @override
  State<UploadAudioScreen> createState() => _UploadAudioScreenState();
}

class _UploadAudioScreenState extends State<UploadAudioScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _thumbnailUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  PlatformFile? _pickedAudioFile;
  String? _pickedAudioFileName;
  int? _pickedAudioFileSize;

  PlatformFile? _pickedThumbnailFile;
  String? _pickedThumbnailFileName;

  bool _loop = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  String? _errorMessage;

  List<WellnessZoneModel> _zones = [];
  StreamSubscription<List<WellnessZoneModel>>? _zonesSub;
  String? _selectedZone;

  bool get _isEditMode => widget.existingAudio != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final a = widget.existingAudio!;
      _titleController.text = a.title;
      _descriptionController.text = a.description;
      _selectedZone = a.category;
      _thumbnailUrlController.text = a.thumbnailUrl;
      _durationController.text = a.duration;
      _loop = a.loop;
    } else if (widget.defaultCategory != null) {
      _selectedZone = widget.defaultCategory!;
    }

    _zonesSub = WellnessZoneService.watchZones().listen((zones) {
      if (mounted) {
        setState(() {
          _zones = zones;
          if (_selectedZone == null && zones.isNotEmpty) {
            _selectedZone = zones.first.name;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _zonesSub?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _thumbnailUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'opus'],
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      double fileSizeInMb = 0;
      if (kIsWeb && file.bytes != null) {
        fileSizeInMb = file.bytes!.length / (1024 * 1024);
      } else if (file.path != null) {
        fileSizeInMb = await File(file.path!).length() / (1024 * 1024);
      }
      if (fileSizeInMb > 100) {
        setState(() => _errorMessage = 'Audio file is too large. Please pick a file under 100MB.');
        return;
      }
      setState(() {
        _pickedAudioFile = file;
        _pickedAudioFileName = file.name;
        _pickedAudioFileSize = file.size;
        _errorMessage = null;
        if (_titleController.text.trim().isEmpty) {
          final cleanName = file.name
              .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
              .replaceAll(RegExp(r'[_-]'), ' ');
          if (cleanName.isNotEmpty) {
            _titleController.text = cleanName[0].toUpperCase() + cleanName.substring(1);
          }
        }
      });
    }
  }

  Future<void> _pickThumbnail() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      double fileSizeInMb = 0;
      if (kIsWeb && file.bytes != null) {
        fileSizeInMb = file.bytes!.length / (1024 * 1024);
      } else if (file.path != null) {
        fileSizeInMb = await File(file.path!).length() / (1024 * 1024);
      }
      if (fileSizeInMb > 15) {
        setState(() => _errorMessage = 'Thumbnail is too large. Pick an image under 15MB.');
        return;
      }
      setState(() {
        _pickedThumbnailFile = file;
        _pickedThumbnailFileName = file.name;
        _errorMessage = null;
      });
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isEditMode && _pickedAudioFile == null) {
      setState(() => _errorMessage = 'Please select an audio file to upload.');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing upload...';
    });

    try {
      String audioUrl = widget.existingAudio?.audioUrl ?? '';
      String duration = _durationController.text.trim();

      if (_pickedAudioFile != null) {
        setState(() => _uploadStatus = 'Uploading audio file to cloud...');
        final audioResult = await VideoService.uploadAudioToCloudinary(
          audioFile: kIsWeb ? null : File(_pickedAudioFile!.path!),
          audioBytes: kIsWeb ? _pickedAudioFile!.bytes : null,
          filename: _pickedAudioFile!.name,
          onProgress: (p) => setState(() {
            _uploadProgress = p * (_pickedThumbnailFile != null ? 0.7 : 0.95);
          }),
        );
        audioUrl = audioResult['audioUrl'] as String;
        if (duration.isEmpty || duration == '0:00') {
          duration = audioResult['duration'] as String;
          _durationController.text = duration;
        }
      }

      String thumbnailUrl = _thumbnailUrlController.text.trim();
      if (_pickedThumbnailFile != null) {
        setState(() => _uploadStatus = 'Uploading thumbnail image...');
        final thumbUrl = await VideoService.uploadImageToCloudinary(
          imageFile: kIsWeb ? null : File(_pickedThumbnailFile!.path!),
          imageBytes: kIsWeb ? _pickedThumbnailFile!.bytes : null,
          filename: _pickedThumbnailFile!.name,
          onProgress: (p) => setState(() {
            _uploadProgress = 0.7 + (p * 0.28);
          }),
        );
        thumbnailUrl = thumbUrl;
      }

      if (audioUrl.isEmpty) {
        throw Exception('Audio file is required. Please select an audio file.');
      }

      setState(() => _uploadStatus = 'Saving track details...');

      final category = _selectedZone ?? 'Sleep Sounds';

      final audio = AudioTrackModel(
        id: _isEditMode ? widget.existingAudio!.id : const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        audioUrl: audioUrl,
        thumbnailUrl: thumbnailUrl,
        duration: duration.isEmpty ? '0:00' : duration,
        category: category,
        loop: _loop,
        createdAt: _isEditMode ? widget.existingAudio!.createdAt : DateTime.now(),
        uploadedBy: 'Admin',
      );

      final service = AudioTrackService();
      if (_isEditMode) {
        await service.updateAudioTrack(audio);
      } else {
        await service.addAudioTrack(audio);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditMode ? '✅ Audio track updated successfully!' : '✅ Audio track uploaded successfully!'),
          backgroundColor: AppTheme.success,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Audio Track' : 'Upload Audio Track'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Banner ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditMode ? 'Edit Audio Track' : 'New Audio Track',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Upload audio files directly with looping and zone selection',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Audio File Picker Card ──────────────────────────────
              const _SectionLabel(label: 'Audio File (Upload Only) *'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _isUploading ? null : _pickAudio,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _pickedAudioFile != null ? AppTheme.primaryIndigo : AppTheme.cardBorder,
                      width: _pickedAudioFile != null ? 2 : 1,
                    ),
                  ),
                  child: _pickedAudioFile != null
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.music_note_rounded, color: AppTheme.primaryIndigo, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedAudioFileName ?? 'audio_file.mp3',
                                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _pickedAudioFileSize != null
                                        ? '${(_pickedAudioFileSize! / (1024 * 1024)).toStringAsFixed(2)} MB • Selected'
                                        : 'Audio file ready',
                                    style: const TextStyle(color: AppTheme.success, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _isUploading ? null : _pickAudio,
                              icon: const Icon(Icons.sync_rounded, size: 16),
                              label: const Text('Change'),
                            ),
                          ],
                        )
                      : _isEditMode && widget.existingAudio != null
                          ? Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 28),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Existing Audio Attached',
                                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      SizedBox(height: 2),
                                      Text('Tap here to replace with a new audio file', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.upload_file_rounded, color: AppTheme.primaryIndigo, size: 22),
                              ],
                            )
                          : Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.audio_file_rounded, color: AppTheme.primaryIndigo, size: 36),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Select Audio File to Upload',
                                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Supports MP3, WAV, M4A, AAC, OGG, FLAC (up to 100 MB)',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Thumbnail Picker Card ───────────────────────────────
              const _SectionLabel(label: 'Thumbnail Image (Optional)'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _isUploading ? null : _pickThumbnail,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _pickedThumbnailFile != null ? AppTheme.primaryIndigo : AppTheme.cardBorder,
                      width: _pickedThumbnailFile != null ? 2 : 1,
                    ),
                  ),
                  child: _pickedThumbnailFile != null
                      ? Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb && _pickedThumbnailFile!.bytes != null
                                  ? Image.memory(
                                      _pickedThumbnailFile!.bytes!,
                                      width: 70,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_pickedThumbnailFile!.path!),
                                      width: 70,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedThumbnailFileName ?? 'Thumbnail',
                                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text('Thumbnail image selected', style: TextStyle(color: AppTheme.success, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.error),
                              onPressed: () => setState(() {
                                _pickedThumbnailFile = null;
                                _pickedThumbnailFileName = null;
                              }),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primaryIndigo, size: 22),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Upload Thumbnail Image',
                                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  SizedBox(height: 2),
                                  Text('JPG, PNG up to 15 MB', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.upload_rounded, color: AppTheme.textSecondary, size: 20),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              _StyledField(
                controller: _thumbnailUrlController,
                hint: 'Or enter Thumbnail Image URL (https://...)',
              ),
              const SizedBox(height: 24),

              // ── Loop Switch Option ──────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _loop ? AppTheme.primaryIndigo.withValues(alpha: 0.5) : AppTheme.cardBorder,
                  ),
                ),
                child: SwitchListTile(
                  value: _loop,
                  activeThumbColor: AppTheme.primaryIndigo,
                  activeTrackColor: AppTheme.primaryIndigo.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (_loop ? AppTheme.primaryIndigo : AppTheme.textSecondary).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.repeat_rounded,
                      color: _loop ? AppTheme.primaryIndigo : AppTheme.textSecondary,
                    ),
                  ),
                  title: const Text(
                    'Loop Audio Track',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    _loop
                        ? 'Audio will seamlessly repeat on loop during sleep/session'
                        : 'Audio will stop after playing once',
                    style: TextStyle(
                      color: _loop ? AppTheme.textSecondary : AppTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  onChanged: (val) => setState(() => _loop = val),
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ────────────────────────────────────────────────
              const _SectionLabel(label: 'Track Title *'),
              const SizedBox(height: 10),
              _StyledField(
                controller: _titleController,
                hint: 'e.g. Deep Forest Rain',
                validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 20),

              // ── Description ──────────────────────────────────────────
              const _SectionLabel(label: 'Description'),
              const SizedBox(height: 10),
              _StyledField(
                controller: _descriptionController,
                hint: 'Describe the track (e.g. Gentle rain sounds to soothe the mind)',
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // ── Zone & Duration Row ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel(label: 'Zone / Category *'),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final defaultAudioZones = [
                              'Sleep Sounds',
                              'Meditation',
                              'Breathwork',
                              'Music',
                              'Wellness',
                              'Sleep Tips',
                              'Stories',
                              'Yoga',
                              'Research',
                              'Nutrition',
                            ];
                            final zoneNames = {
                              ...defaultAudioZones,
                              ..._zones.map((z) => z.name),
                              if (_selectedZone != null) _selectedZone!,
                            }.toList();
                            final currentValue = zoneNames.contains(_selectedZone) ? _selectedZone : zoneNames.first;

                            return DropdownButtonFormField<String>(
                              value: currentValue,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppTheme.surfaceElevated,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppTheme.primaryIndigo, width: 2),
                                ),
                              ),
                              dropdownColor: AppTheme.surfaceElevated,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                              items: zoneNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                              onChanged: widget.defaultCategory != null ? null : (v) {
                                if (v != null) setState(() => _selectedZone = v);
                              },
                              validator: (v) => v == null || v.isEmpty ? 'Zone is required' : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel(label: 'Duration'),
                        const SizedBox(height: 10),
                        _StyledField(
                          controller: _durationController,
                          hint: 'e.g. 10:00 (auto-set)',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Progress & Error ─────────────────────────────────────
              if (_isUploading) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryIndigo),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _uploadStatus,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            '${(_uploadProgress * 100).toInt()}%',
                            style: const TextStyle(color: AppTheme.primaryIndigo, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _uploadProgress > 0 ? _uploadProgress : null,
                          backgroundColor: AppTheme.surface,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryIndigo),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Submit Button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isEditMode ? 'Update Audio Track' : 'Save & Upload Audio',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared Widgets ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        filled: true,
        fillColor: AppTheme.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryIndigo, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.error, width: 2),
        ),
      ),
    );
  }
}

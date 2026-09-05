import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import '../../videos/models/video_model.dart';
import '../../videos/services/video_service.dart';
import '../models/wellness_zone_model.dart';
import '../services/wellness_zone_service.dart';

class UploadVideoScreen extends StatefulWidget {
  final VideoModel? existingVideo;
  final String? defaultCategory;
  const UploadVideoScreen({super.key, this.existingVideo, this.defaultCategory});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  PlatformFile? _pickedFile;
  String? _pickedFileName;
  PlatformFile? _pickedThumbnailFile;
  String? _pickedThumbnailFileName;

  bool _isUploading = false;
  bool _isLinkMode = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;
  final _linkUrlController = TextEditingController();
  final _thumbnailUrlController = TextEditingController();

  List<WellnessZoneModel> _zones = [];
  StreamSubscription<List<WellnessZoneModel>>? _zonesSub;
  String? _selectedZone;

  bool get _isEditMode => widget.existingVideo != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final v = widget.existingVideo!;
      _titleController.text = v.title;
      _descriptionController.text = v.description;
      _tagsController.text = v.tags.join(', ');
      _isLinkMode = true; // For editing, we usually treat existing media as a link so we don't re-upload by default
      _linkUrlController.text = v.videoUrl;
      _thumbnailUrlController.text = v.thumbnailUrl;
      _selectedZone = v.category;
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
    _tagsController.dispose();
    _linkUrlController.dispose();
    _thumbnailUrlController.dispose();
    super.dispose();
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

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
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
      if (fileSizeInMb > 200) {
        setState(() => _errorMessage = 'File is too large. Please pick a video under 200MB.');
        return;
      }
      setState(() {
        _pickedFile = file;
        _pickedFileName = file.name;
        _errorMessage = null;
      });
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_isLinkMode && _pickedFile == null) {
      setState(() => _errorMessage = 'Please pick a video file first.');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _uploadProgress = 0.0;
    });

    try {
      String finalVideoUrl;
      String finalThumbUrl = '';

      if (_isLinkMode) {
        finalVideoUrl = _linkUrlController.text.trim();
        finalThumbUrl = _thumbnailUrlController.text.trim();
        if (finalVideoUrl.isEmpty) {
          throw Exception('Video URL is required in Link Mode.');
        }
      } else {
        final urls = await VideoService.uploadVideoToCloudinary(
          videoFile: kIsWeb ? null : File(_pickedFile!.path!),
          videoBytes: kIsWeb ? _pickedFile!.bytes : null,
          filename: _pickedFile!.name,
          onProgress: (p) => setState(() => _uploadProgress = p * 0.7),
        );
        finalVideoUrl = urls['videoUrl']!;
        finalThumbUrl = urls['thumbnailUrl']!;
      }

      if (_pickedThumbnailFile != null) {
        final customThumb = await VideoService.uploadImageToCloudinary(
          imageFile: kIsWeb ? null : File(_pickedThumbnailFile!.path!),
          imageBytes: kIsWeb ? _pickedThumbnailFile!.bytes : null,
          filename: _pickedThumbnailFile!.name,
          onProgress: (p) => setState(() => _uploadProgress = 0.7 + (p * 0.3)),
        );
        finalThumbUrl = customThumb;
      }

      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final category = _selectedZone ?? 'Wellness Videos';

      if (_isEditMode) {
        await VideoService.updateVideo(
          id: widget.existingVideo!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          videoUrl: finalVideoUrl,
          thumbnailUrl: finalThumbUrl,
          category: category,
          tags: tags,
        );
      } else {
        await VideoService.saveVideo(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          videoUrl: finalVideoUrl,
          thumbnailUrl: finalThumbUrl,
          category: category,
          tags: tags,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? '✅ Video updated successfully!' : '✅ Video uploaded successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
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
        title: Text(_isEditMode ? 'Edit Video' : 'Upload Video'),
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
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C91FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.video_library_rounded, color: Colors.white, size: 32),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditMode ? 'Edit Video' : 'New Video',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _isEditMode ? 'Update existing video details' : 'Upload a wellness video for all users',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Mode Toggle ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Upload File', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                      value: false,
                      groupValue: _isLinkMode,
                      activeColor: AppTheme.primaryIndigo,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setState(() => _isLinkMode = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Link URL', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                      value: true,
                      groupValue: _isLinkMode,
                      activeColor: AppTheme.primaryIndigo,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setState(() => _isLinkMode = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Source Selection ───────────────────────────────────────────
              if (!_isLinkMode) ...[
                _SectionLabel(label: 'Video File'),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _isUploading ? null : _pickVideo,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _pickedFile != null
                            ? AppTheme.primaryIndigo
                            : AppTheme.cardBorder,
                        width: _pickedFile != null ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _pickedFile != null
                              ? Icons.check_circle_rounded
                              : Icons.cloud_upload_rounded,
                          color: _pickedFile != null
                              ? AppTheme.success
                              : AppTheme.primaryIndigo,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _pickedFileName ?? 'Tap to select a video',
                          style: TextStyle(
                            color: _pickedFile != null
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_pickedFile == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'MP4, MOV up to 200 MB',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                _SectionLabel(label: 'Video URL'),
                const SizedBox(height: 10),
                _StyledField(
                  controller: _linkUrlController,
                  hint: 'https://example.com/video.mp4',
                  validator: (v) =>
                      _isLinkMode && (v == null || v.trim().isEmpty) ? 'URL is required' : null,
                ),
                const SizedBox(height: 20),
                _SectionLabel(label: 'Thumbnail URL (Optional)'),
                const SizedBox(height: 10),
                _StyledField(
                  controller: _thumbnailUrlController,
                  hint: 'https://example.com/thumb.jpg',
                ),
              ],
              const SizedBox(height: 24),

              // ── Custom Thumbnail Picker ──────────────────────────────
              _SectionLabel(label: 'Thumbnail Image (Optional)'),
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
                                    _pickedThumbnailFileName ?? 'Custom Thumbnail',
                                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text('Custom thumbnail selected', style: TextStyle(color: AppTheme.success, fontSize: 12)),
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
                              child: const Icon(Icons.image_rounded, color: AppTheme.primaryIndigo, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Upload Custom Thumbnail',
                                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isLinkMode
                                        ? 'Pick an image file or enter URL above'
                                        : 'Leave empty to auto-generate from video',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primaryIndigo),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ────────────────────────────────────────────────
              _SectionLabel(label: 'Title'),
              const SizedBox(height: 10),
              _StyledField(
                controller: _titleController,
                hint: 'e.g. Breathing for Better Sleep',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 20),

              // ── Description ──────────────────────────────────────────
              _SectionLabel(label: 'Description'),
              const SizedBox(height: 10),
              _StyledField(
                controller: _descriptionController,
                hint: 'Describe what users will learn...',
                maxLines: 5,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 20),

              // ── Category / Zone Dropdown ──────────────────────────────
              _SectionLabel(label: 'Zone'),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final defaultVideoZones = [
                    'Wellness Videos',
                    'Meditation',
                    'Sleep Sounds',
                    'Breathwork',
                    'Music',
                    'Yoga',
                    'Sleep Tips',
                    'Wellness',
                    'Stories',
                    'Research',
                    'Nutrition',
                    'Exercise',
                  ];
                  final zoneNames = {
                    ...defaultVideoZones,
                    ..._zones.map((z) => z.name),
                    if (_selectedZone != null) _selectedZone!,
                  }.toList();
                  final currentValue = zoneNames.contains(_selectedZone) ? _selectedZone : zoneNames.first;

                  return DropdownButtonFormField<String>(
                    value: currentValue,
                    dropdownColor: AppTheme.surfaceElevated,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surfaceElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryIndigo, width: 2)),
                    ),
                    items: zoneNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedZone = val);
                    },
                    validator: (v) => v == null || v.isEmpty ? 'Zone is required' : null,
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── Tags ─────────────────────────────────────────────────
              _SectionLabel(label: 'Tags (optional, comma separated)'),
              const SizedBox(height: 10),
              _StyledField(
                controller: _tagsController,
                hint: 'e.g. Relaxation, Breathing, Sleep',
              ),
              const SizedBox(height: 32),

              // ── Error ────────────────────────────────────────────────
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

              // ── Upload Progress ──────────────────────────────────────
              if (_isUploading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Uploading...',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${(_uploadProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: AppTheme.primaryIndigo,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        minHeight: 8,
                        backgroundColor: AppTheme.surfaceElevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryIndigo,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ],

              // ── Submit Button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                  label: Text(
                    _isUploading ? 'Uploading...' : 'Upload Video',
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

import 'package:flutter/material.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import 'package:uuid/uuid.dart';
import '../../audio/models/audio_track_model.dart';
import '../../audio/services/audio_track_service.dart';

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
  final _categoryController = TextEditingController();
  final _audioUrlController = TextEditingController();
  final _thumbnailUrlController = TextEditingController();
  final _durationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isUploading = false;
  String? _errorMessage;

  bool get _isEditMode => widget.existingAudio != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final a = widget.existingAudio!;
      _titleController.text = a.title;
      _descriptionController.text = a.description;
      _categoryController.text = a.category;
      _audioUrlController.text = a.audioUrl;
      _thumbnailUrlController.text = a.thumbnailUrl;
      _durationController.text = a.duration;
    } else if (widget.defaultCategory != null) {
      _categoryController.text = widget.defaultCategory!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _audioUrlController.dispose();
    _thumbnailUrlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final audio = AudioTrackModel(
        id: _isEditMode ? widget.existingAudio!.id : const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        audioUrl: _audioUrlController.text.trim(),
        thumbnailUrl: _thumbnailUrlController.text.trim(),
        duration: _durationController.text.trim(),
        category: _categoryController.text.trim(),
        createdAt: _isEditMode ? widget.existingAudio!.createdAt : DateTime.now(),
        uploadedBy: 'Admin',
      );

      final service = AudioTrackService();
      if (_isEditMode) {
        // We'll just delete and re-add for simplicity in this demo if needed,
        // or just add if it's new. Wait, let's just add it.
        await service.deleteAudioTrack(audio.id);
      }
      await service.addAudioTrack(audio);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Audio saved successfully!'),
          backgroundColor: AppTheme.success,
        ));
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Audio' : 'Upload Audio'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.error)),
                ),

              const Text('Title', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('e.g. Deep Sleep River'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              const Text('Description', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Describe the audio...'),
              ),
              const SizedBox(height: 20),

              const Text('Category', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _categoryController,
                readOnly: widget.defaultCategory != null,
                style: TextStyle(color: widget.defaultCategory != null ? AppTheme.textSecondary : Colors.white),
                decoration: _inputDeco('e.g. Sleep Sounds, Meditation'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              const Text('Duration', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _durationController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('e.g. 10:00'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              const Text('Audio URL', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _audioUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('https://.../audio.mp3'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              const Text('Thumbnail URL', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _thumbnailUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('https://.../image.jpg'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isUploading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Audio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textSecondary),
      filled: true,
      fillColor: AppTheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.cardBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryIndigo)),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import 'package:snore_clinics/core/utils/docx_converter.dart';
import '../../blogs/models/blog_model.dart';
import '../../blogs/services/blog_service.dart';
import '../../videos/services/video_service.dart';
import '../models/wellness_zone_model.dart';
import '../services/wellness_zone_service.dart';

class UploadBlogScreen extends StatefulWidget {
  final BlogModel? existingBlog;
  final String? defaultCategory;
  const UploadBlogScreen({super.key, this.existingBlog, this.defaultCategory});

  @override
  State<UploadBlogScreen> createState() => _UploadBlogScreenState();
}

class _UploadBlogScreenState extends State<UploadBlogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _coverImageController = TextEditingController();
  final _authorController = TextEditingController();
  final _readTimeController = TextEditingController();
  final _tagsController = TextEditingController();

  PlatformFile? _pickedCoverImageFile;
  String? _pickedCoverImageFileName;
  List<WellnessZoneModel> _zones = [];
  StreamSubscription<List<WellnessZoneModel>>? _zonesSub;
  String? _selectedCategory;

  bool _isUploading = false;
  String? _errorMessage;

  bool get _isEditMode => widget.existingBlog != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final b = widget.existingBlog!;
      _titleController.text = b.title;
      _summaryController.text = b.summary;
      _contentController.text = b.content;
      _coverImageController.text = b.coverImageUrl;
      _authorController.text = b.author;
      _readTimeController.text = b.readTimeMinutes.toString();
      _tagsController.text = b.tags.join(', ');
      _selectedCategory = b.category;
    } else if (widget.defaultCategory != null) {
      _selectedCategory = widget.defaultCategory!;
    }

    _zonesSub = WellnessZoneService.watchZones().listen((zones) {
      if (mounted) {
        setState(() {
          _zones = zones;
          if (_selectedCategory == null && zones.isNotEmpty) {
            _selectedCategory = zones.first.name;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _zonesSub?.cancel();
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _coverImageController.dispose();
    _authorController.dispose();
    _readTimeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
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
        setState(() => _errorMessage = 'Image is too large. Pick an image under 15MB.');
        return;
      }
      setState(() {
        _pickedCoverImageFile = file;
        _pickedCoverImageFileName = file.name;
        _errorMessage = null;
      });
    }
  }

  /// Picks a .docx file and auto-populates all form fields.
  Future<void> _pickWordDoc() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final bytes = result.files.single.bytes!;
    final parsed = DocxConverter.convert(bytes);

    setState(() {
      if (parsed.title.isNotEmpty) _titleController.text = parsed.title;
      if (parsed.content.isNotEmpty) _contentController.text = parsed.content;
      if (parsed.summary.isNotEmpty) _summaryController.text = parsed.summary;

      // Estimate read time: ~200 words per minute
      final wordCount = parsed.content.split(RegExp(r'\s+')).length;
      final readMins = (wordCount / 200).ceil().clamp(1, 60);
      _readTimeController.text = readMins.toString();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Document imported! Please review and fill in missing fields.'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      String finalCoverUrl = _coverImageController.text.trim();
      if (_pickedCoverImageFile != null) {
        finalCoverUrl = await VideoService.uploadImageToCloudinary(
          imageFile: kIsWeb ? null : File(_pickedCoverImageFile!.path!),
          imageBytes: kIsWeb ? _pickedCoverImageFile!.bytes : null,
          filename: _pickedCoverImageFile!.name,
        );
      }
      if (finalCoverUrl.isEmpty) {
        throw Exception('Please upload a cover image or provide an image URL.');
      }

      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final readTime = int.tryParse(_readTimeController.text.trim()) ?? 5;
      final category = _selectedCategory ?? 'Wellness';

      if (_isEditMode) {
        await BlogService.updateBlog(
          id: widget.existingBlog!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          summary: _summaryController.text.trim(),
          coverImageUrl: finalCoverUrl,
          category: category,
          author: _authorController.text.trim(),
          readTimeMinutes: readTime,
          tags: tags,
        );
      } else {
        await BlogService.saveBlog(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          summary: _summaryController.text.trim(),
          coverImageUrl: finalCoverUrl,
          category: category,
          author: _authorController.text.trim(),
          readTimeMinutes: readTime,
          tags: tags,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? '✅ Blog updated successfully!' : '✅ Blog saved successfully!'),
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
        title: Text(_isEditMode ? 'Edit Blog/Story' : 'New Blog/Story'),
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
                    colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_stories_rounded, color: Colors.white, size: 32),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Publish Content',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Write a new blog post or story',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Word Doc Import ──────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickWordDoc,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.upload_file_rounded,
                              color: AppTheme.primaryIndigo,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Import from Word (.docx)',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Auto-extracts headings, bullets, and text formatting',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Title ────────────────────────────────────────────────
              _SectionLabel(label: 'Title'),
              const SizedBox(height: 10),
              _StyledField(
                controller: _titleController,
                hint: 'e.g. 5 Habits for Better Sleep',
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // ── Summary ──────────────────────────────────────────────
              _SectionLabel(label: 'Summary (Short excerpt)'),
              const SizedBox(height: 10),
              _StyledField(
                controller: _summaryController,
                hint: 'A quick 1-2 sentence preview...',
                maxLines: 2,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // ── Content ──────────────────────────────────────────────
              _SectionLabel(label: 'Content (Markdown Supported)'),
              const SizedBox(height: 10),
              _StyledField(
                controller: _contentController,
                hint: 'Write the full blog post here. You can use **bold**, # headings, etc.',
                maxLines: 15,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // ── Cover Image / Thumbnail Picker ──────────────────────
              _SectionLabel(label: 'Cover Image / Thumbnail'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _isUploading ? null : _pickCoverImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _pickedCoverImageFile != null ? AppTheme.primaryIndigo : AppTheme.cardBorder,
                      width: _pickedCoverImageFile != null ? 2 : 1,
                    ),
                  ),
                  child: _pickedCoverImageFile != null
                      ? Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb && _pickedCoverImageFile!.bytes != null
                                  ? Image.memory(
                                      _pickedCoverImageFile!.bytes!,
                                      width: 70,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_pickedCoverImageFile!.path!),
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
                                    _pickedCoverImageFileName ?? 'Custom Thumbnail',
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
                                _pickedCoverImageFile = null;
                                _pickedCoverImageFileName = null;
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
                                    'Upload Thumbnail / Cover Image',
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
                controller: _coverImageController,
                hint: 'Or enter Cover Image URL (https://...)',
                validator: (v) {
                  if (_pickedCoverImageFile != null) return null;
                  if (v == null || v.trim().isEmpty) {
                    return 'Please upload an image or provide an image URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Zone / Category & Read Time ─────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'Zone / Category'),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final defaultBlogZones = [
                              'Sleep Tips',
                              'Wellness',
                              'Stories',
                              'Research',
                              'Nutrition',
                              'Exercise',
                              'Meditation',
                              'Sleep Sounds',
                              'Breathwork',
                              'Music',
                              'Yoga',
                            ];
                            final zoneNames = {
                              ...defaultBlogZones,
                              ..._zones.map((z) => z.name),
                              if (_selectedCategory != null) _selectedCategory!,
                            }.toList();
                            final currentValue = zoneNames.contains(_selectedCategory) ? _selectedCategory : zoneNames.first;

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
                                if (v != null) setState(() => _selectedCategory = v);
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
                        _SectionLabel(label: 'Min. Read'),
                        const SizedBox(height: 10),
                        _StyledField(
                          controller: _readTimeController,
                          hint: '5',
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Req.' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Author & Tags ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'Author'),
                        const SizedBox(height: 10),
                        _StyledField(
                          controller: _authorController,
                          hint: 'Dr. Smith',
                          validator: (v) => v == null || v.trim().isEmpty ? 'Req.' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'Tags (comma separated)'),
                        const SizedBox(height: 10),
                        _StyledField(
                          controller: _tagsController,
                          hint: 'Sleep, Tips',
                        ),
                      ],
                    ),
                  ),
                ],
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
                      _isEditMode ? 'Update Blog' : 'Publish Blog',
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
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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

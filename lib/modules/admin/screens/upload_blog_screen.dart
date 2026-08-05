import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import 'package:snore_clinics/core/utils/docx_converter.dart';
import '../../blogs/models/blog_model.dart';
import '../../blogs/services/blog_service.dart';

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

  String _selectedCategory = 'Wellness';
  bool _isUploading = false;
  String? _errorMessage;

  final List<String> _categories = [
    'Sleep Tips',
    'Wellness',
    'Stories',
    'Research',
    'Nutrition',
    'Exercise',
  ];

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
      if (_categories.contains(b.category)) {
        _selectedCategory = b.category;
      } else {
        _categories.add(b.category);
        _selectedCategory = b.category;
      }
    } else if (widget.defaultCategory != null) {
      if (!_categories.contains(widget.defaultCategory!)) {
        _categories.add(widget.defaultCategory!);
      }
      _selectedCategory = widget.defaultCategory!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _coverImageController.dispose();
    _authorController.dispose();
    _readTimeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  /// Picks a .docx file and auto-populates all form fields.
  Future<void> _pickWordDoc() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final bytes = result.files.single.bytes! as Uint8List;
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
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final readTime = int.tryParse(_readTimeController.text.trim()) ?? 5;

      if (_isEditMode) {
        await BlogService.updateBlog(
          id: widget.existingBlog!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          summary: _summaryController.text.trim(),
          coverImageUrl: _coverImageController.text.trim(),
          category: _selectedCategory,
          author: _authorController.text.trim(),
          readTimeMinutes: readTime,
          tags: tags,
        );
      } else {
        await BlogService.saveBlog(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          summary: _summaryController.text.trim(),
          coverImageUrl: _coverImageController.text.trim(),
          category: _selectedCategory,
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

              // ── Cover Image URL ──────────────────────────────────────
              _SectionLabel(label: 'Cover Image URL'),
              const SizedBox(height: 10),
              _StyledField(
                controller: _coverImageController,
                hint: 'https://example.com/image.jpg',
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // ── Category & Read Time ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'Category'),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.surfaceElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppTheme.cardBorder),
                            ),
                          ),
                          dropdownColor: AppTheme.surfaceElevated,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: widget.defaultCategory != null ? null : (v) => setState(() => _selectedCategory = v!),
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

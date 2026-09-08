import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:snore_clinics/core/theme/app_theme.dart';
import '../models/quick_access_model.dart';
import '../services/quick_access_service.dart';
import '../../videos/services/video_service.dart';
import '../models/wellness_zone_model.dart';
import '../services/wellness_zone_service.dart';

class UploadQuickAccessScreen extends StatefulWidget {
  final QuickAccessModel? existingItem;
  const UploadQuickAccessScreen({super.key, this.existingItem});

  @override
  State<UploadQuickAccessScreen> createState() => _UploadQuickAccessScreenState();
}

class _UploadQuickAccessScreenState extends State<UploadQuickAccessScreen> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  PlatformFile? _pickedThumbnailFile;
  String? _pickedThumbnailFileName;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;
  final _thumbnailUrlController = TextEditingController();

  String _selectedRoute = 'custom';
  List<WellnessZoneModel> _zones = [];
  StreamSubscription? _zoneSub;

  final Map<String, String> _builtInRoutes = {
    'custom': 'Custom URL / Other',
    '/sleep-history': 'Sleep Diary',
    'route:/wellness': 'Wellness Hub (Yoga)',
    '/relaxation': 'Meditation',
    'route:/snore_track': 'Snore Track',
    'route:/sleep_stages': 'Sleep Stages',
    '/journal': 'Journal List',
    '/insights': 'Nidra AI Insights',
    '/daily_sleep_goal': 'Daily Sleep Goal',
  };

  bool get _isEditMode => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    _zoneSub = WellnessZoneService.watchZones().listen((zones) {
      if (mounted) {
        setState(() => _zones = zones);
      }
    });
    if (_isEditMode) {
      final item = widget.existingItem!;
      _titleController.text = item.title;
      _targetController.text = item.target;
      _thumbnailUrlController.text = item.thumbnailUrl;
      
      // Determine if the target is a built-in route
      if (_builtInRoutes.containsKey(item.target)) {
        _selectedRoute = item.target;
      } else {
        _selectedRoute = 'custom';
      }
    }
  }

  @override
  void dispose() {
    _zoneSub?.cancel();
    _titleController.dispose();
    _targetController.dispose();
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

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_titleController.text.trim().isEmpty || _targetController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Title and Target are required.');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _uploadProgress = 0.0;
    });

    try {
      String finalThumbUrl = _thumbnailUrlController.text.trim();

      if (_pickedThumbnailFile != null) {
        final customThumb = await VideoService.uploadImageToCloudinary(
          imageFile: kIsWeb ? null : File(_pickedThumbnailFile!.path!),
          imageBytes: kIsWeb ? _pickedThumbnailFile!.bytes : null,
          filename: _pickedThumbnailFile!.name,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
        finalThumbUrl = customThumb;
      }

      if (_isEditMode) {
        await QuickAccessService.updateItem(
          id: widget.existingItem!.id,
          title: _titleController.text.trim(),
          target: _targetController.text.trim(),
          thumbnailUrl: finalThumbUrl,
        );
      } else {
        await QuickAccessService.createItem(
          title: _titleController.text.trim(),
          target: _targetController.text.trim(),
          thumbnailUrl: finalThumbUrl,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Quick Access' : 'Add Quick Access'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  ),

                // Title
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Meditation, Snore Track',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                // Target Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedRoute,
                  dropdownColor: AppTheme.surfaceElevated,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Target Type / Route / Zone',
                  ),
                  items: [
                    ..._builtInRoutes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                    if (_zones.isNotEmpty)
                      ..._zones.map((z) => DropdownMenuItem(
                            value: 'zone:${z.id}',
                            child: Row(
                              children: [
                                const Icon(Icons.eco_rounded, size: 16, color: AppTheme.accentTeal),
                                const SizedBox(width: 8),
                                Text('Zone: ${z.name}', style: const TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _selectedRoute = v ?? 'custom';
                      if (_selectedRoute.startsWith('zone:')) {
                        final zoneId = _selectedRoute.substring('zone:'.length);
                        final matched = _zones.firstWhere((z) => z.id == zoneId, orElse: () => _zones.first);
                        _targetController.text = _selectedRoute;
                        if (_titleController.text.trim().isEmpty || _zones.any((z) => z.name == _titleController.text.trim())) {
                          _titleController.text = matched.name;
                        }
                      } else if (_selectedRoute != 'custom') {
                        _targetController.text = _selectedRoute;
                      } else {
                        _targetController.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Custom Target
                if (_selectedRoute == 'custom') ...[
                  TextFormField(
                    controller: _targetController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Custom Target URL or Route',
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                ],

                // Thumbnail Upload
                const Text(
                  'Thumbnail Image',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickThumbnail,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryIndigo.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.image_outlined, color: AppTheme.primaryIndigo, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          _pickedThumbnailFileName ?? 'Tap to pick an image from device',
                          style: const TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                const Center(
                  child: Text('OR', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _thumbnailUrlController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Paste Image URL instead',
                  ),
                ),
                const SizedBox(height: 40),

                // Upload Button
                if (_isUploading)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: AppTheme.surfaceElevated,
                        color: AppTheme.primaryIndigo,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading... ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: _upload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryIndigo,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _isEditMode ? 'Update Quick Access' : 'Create Quick Access',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

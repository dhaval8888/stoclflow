import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../data/models/product_image_model.dart';

class ProductImagePickerWidget extends StatefulWidget {
  final List<ProductImageModel> existingImages;
  final Future<void> Function(File file, void Function(double progress) onProgress)? onUpload;
  final Future<void> Function(String imageId)? onDelete;
  final bool readOnly;

  const ProductImagePickerWidget({
    super.key,
    this.existingImages = const [],
    this.onUpload,
    this.onDelete,
    this.readOnly = false,
  });

  @override
  State<ProductImagePickerWidget> createState() => _ProductImagePickerWidgetState();
}

class _ProductImagePickerWidgetState extends State<ProductImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;
  File? _pendingFile;

  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked == null) return;

      final file = File(picked.path);
      final size = await file.length();

      if (size > _maxFileSizeBytes) {
        setState(() {
          _uploadError = 'File size exceeds 5MB limit. Please choose a smaller image.';
        });
        return;
      }

      _pendingFile = file;
      await _startUpload(file);
    } catch (e) {
      setState(() {
        _uploadError = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _startUpload(File file) async {
    if (widget.onUpload == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });

    try {
      await widget.onUpload!(file, (progress) {
        if (mounted) {
          setState(() => _uploadProgress = progress);
        }
      });
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 1.0;
          _pendingFile = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Product Images',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            if (!widget.readOnly && widget.onUpload != null)
              TextButton.icon(
                onPressed: _isUploading ? null : _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Add Image'),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),

        // Upload progress indicator
        if (_isUploading) ...[
          Container(
            padding: const EdgeInsets.all(AppDimensions.space12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Uploading image (${(_uploadProgress * 100).toInt()}%)...',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space12),
        ],

        // Upload failure & Retry banner
        if (_uploadError != null) ...[
          Container(
            padding: const EdgeInsets.all(AppDimensions.space12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 20, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _uploadError!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
                if (_pendingFile != null)
                  TextButton(
                    onPressed: () => _startUpload(_pendingFile!),
                    child: const Text('Retry', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space12),
        ],

        // Gallery of Images
        if (widget.existingImages.isEmpty && !_isUploading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.space24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 40,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                const SizedBox(height: 8),
                Text(
                  'No product images uploaded',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.existingImages.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppDimensions.space12),
              itemBuilder: (context, index) {
                final image = widget.existingImages[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      child: Container(
                        width: 96,
                        height: 96,
                        color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
                        child: CachedNetworkImage(
                          imageUrl: image.url,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, _, _) => const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                    if (image.isPrimary)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Main',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    if (!widget.readOnly && widget.onDelete != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => widget.onDelete!(image.id),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

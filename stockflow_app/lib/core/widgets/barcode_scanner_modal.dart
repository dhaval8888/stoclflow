import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../constants/dimensions.dart';
import '../theme/colors.dart';
import 'app_button.dart';
import 'app_text_field.dart';

class BarcodeScannerModal extends StatefulWidget {
  final String title;

  const BarcodeScannerModal({
    super.key,
    this.title = 'Scan Barcode',
  });

  static Future<String?> show(BuildContext context, {String title = 'Scan Barcode'}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BarcodeScannerModal(title: title),
    );
  }

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal> {
  late final MobileScannerController _controller;
  final TextEditingController _manualController = TextEditingController();
  bool _isProcessing = false;
  bool _showManualInput = false;
  bool _torchEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return; // Prevent duplicate rapid scans

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawCode = barcodes.first.rawValue;
    if (rawCode == null || rawCode.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    Navigator.of(context).pop(rawCode.trim());
  }

  void _submitManual() {
    final code = _manualController.text.trim();
    if (code.isNotEmpty) {
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                Row(
                  children: [
                    if (!_showManualInput) ...[
                      IconButton(
                        icon: Icon(
                          _torchEnabled ? Icons.flash_on : Icons.flash_off,
                          color: _torchEnabled ? Colors.amber : null,
                        ),
                        onPressed: () async {
                          await _controller.toggleTorch();
                          setState(() => _torchEnabled = !_torchEnabled);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios_outlined),
                        onPressed: () => _controller.switchCamera(),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Body: Scanner View or Manual Input
          Expanded(
            child: _showManualInput
                ? Padding(
                    padding: const EdgeInsets.all(AppDimensions.space24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enter Barcode or SKU manually',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppDimensions.space16),
                        AppTextField(
                          label: 'Barcode / SKU',
                          hint: 'e.g. 8901234567890',
                          controller: _manualController,
                          prefixIcon: Icons.qr_code,
                          keyboardType: TextInputType.number,
                          onSubmitted: (_) => _submitManual(),
                        ),
                        const SizedBox(height: AppDimensions.space24),
                        AppButton(
                          text: 'Look Up Product',
                          onPressed: _submitManual,
                        ),
                      ],
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                        child: MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                          errorBuilder: (context, error, child) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppDimensions.space24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam_off_outlined, size: 48, color: AppColors.error),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Camera unavailable: ${error.errorCode.name}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => setState(() => _showManualInput = true),
                                      child: const Text('Use Manual Entry'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Scanning Frame overlay
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.accent, width: 2.5),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                        ),
                      ),

                      // Instruction pill
                      Positioned(
                        bottom: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Align barcode within the frame',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // Bottom switch button
          Padding(
            padding: const EdgeInsets.all(AppDimensions.space16),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showManualInput = !_showManualInput),
              icon: Icon(_showManualInput ? Icons.camera_alt_outlined : Icons.keyboard_alt_outlined, size: 18),
              label: Text(_showManualInput ? 'Switch to Camera' : 'Enter Barcode Manually'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

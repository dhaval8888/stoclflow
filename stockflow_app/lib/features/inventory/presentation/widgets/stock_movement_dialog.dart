import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../application/inventory_controller.dart';
import '../../data/models/inventory_item_model.dart';

class StockMovementDialog extends ConsumerStatefulWidget {
  final InventoryItemModel item;
  final String initialType;

  const StockMovementDialog({
    super.key,
    required this.item,
    this.initialType = 'STOCK_IN',
  });

  static Future<bool?> show(
    BuildContext context, {
    required InventoryItemModel item,
    String initialType = 'STOCK_IN',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StockMovementDialog(item: item, initialType: initialType),
    );
  }

  @override
  ConsumerState<StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends ConsumerState<StockMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _movementType;
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _movementType = widget.initialType;
    if (_movementType == 'ADJUSTMENT') {
      _qtyController.text = widget.item.currentQuantity.toString();
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final entered = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (entered <= 0 && _movementType != 'ADJUSTMENT') {
      setState(() => _errorMessage = 'Quantity must be greater than 0');
      return;
    }
    if (_movementType == 'STOCK_OUT' && entered > widget.item.currentQuantity) {
      setState(() => _errorMessage = 'Cannot remove more stock than currently available (${widget.item.currentQuantity})');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(inventoryControllerProvider.notifier).performMovement(
            productId: widget.item.productId,
            type: _movementType,
            quantity: entered,
            note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final enteredVal = int.tryParse(_qtyController.text.trim()) ?? 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Inventory Movement',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              item.productName,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.space12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space16),
                  ],

                  // Current Stock Indicator
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.space12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Available Stock:', style: TextStyle(fontSize: 13)),
                        Text(
                          '${item.currentQuantity} ${item.unit}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // Movement Type Segmented Buttons
                  Text(
                    'Operation Type',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'STOCK_IN',
                        label: Text('Stock In'),
                        icon: Icon(Icons.add_circle_outline, size: 16),
                      ),
                      ButtonSegment(
                        value: 'STOCK_OUT',
                        label: Text('Stock Out'),
                        icon: Icon(Icons.remove_circle_outline, size: 16),
                      ),
                      ButtonSegment(
                        value: 'ADJUSTMENT',
                        label: Text('Adjustment'),
                        icon: Icon(Icons.tune, size: 16),
                      ),
                    ],
                    selected: {_movementType},
                    onSelectionChanged: (val) {
                      setState(() {
                        _movementType = val.first;
                        _errorMessage = null;
                        if (_movementType == 'ADJUSTMENT') {
                          _qtyController.text = item.currentQuantity.toString();
                        } else {
                          _qtyController.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // Quantity Field
                  AppTextField(
                    label: _movementType == 'STOCK_IN'
                        ? 'Quantity to Add'
                        : (_movementType == 'STOCK_OUT'
                            ? 'Quantity to Deduct'
                            : 'Physical Count (Verified Stock)'),
                    hint: _movementType == 'ADJUSTMENT' ? '${item.currentQuantity}' : '0',
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    prefixIcon: _movementType == 'STOCK_IN'
                        ? Icons.add
                        : (_movementType == 'STOCK_OUT' ? Icons.remove : Icons.check_circle_outline),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Quantity is required';
                      final n = int.tryParse(v.trim());
                      if (n == null) return 'Must be a valid integer';
                      if (_movementType != 'ADJUSTMENT' && n <= 0) return 'Must be greater than 0';
                      if (_movementType == 'ADJUSTMENT' && n < 0) return 'Count cannot be negative';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.space12),

                  // Live Preview Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.space12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _movementType == 'STOCK_IN'
                              ? 'Result: ${item.currentQuantity} + $enteredVal = ${item.currentQuantity + enteredVal} ${item.unit}'
                              : (_movementType == 'STOCK_OUT'
                                  ? 'Result: ${item.currentQuantity} - $enteredVal = ${item.currentQuantity - enteredVal} ${item.unit}'
                                  : 'Physical Count Result: New Stock = $enteredVal ${item.unit} (Delta: ${enteredVal - item.currentQuantity >= 0 ? '+' : ''}${enteredVal - item.currentQuantity} ${item.unit})'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent),
                        ),
                        if (_movementType == 'ADJUSTMENT') ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Physical count updates the final stock count and records the exact audit delta.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // Note
                  AppTextField(
                    label: 'Reason / Note (Optional)',
                    hint: _movementType == 'STOCK_IN'
                        ? 'e.g. Supplier delivery PO #123'
                        : (_movementType == 'STOCK_OUT' ? 'e.g. Damaged goods / expired' : 'e.g. Month-end shelf audit'),
                    controller: _noteController,
                    prefixIcon: Icons.comment_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppDimensions.space24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(
                        child: AppButton(
                          text: 'Confirm Movement',
                          isLoading: _isLoading,
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

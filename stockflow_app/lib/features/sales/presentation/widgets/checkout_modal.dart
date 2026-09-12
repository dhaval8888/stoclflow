import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../inventory/application/inventory_controller.dart';
import '../../../products/application/products_controller.dart';
import '../../application/cart_controller.dart';
import '../../application/sales_history_controller.dart';
import '../../data/repositories/sales_repository.dart';
import '../screens/receipt_screen.dart';

class CheckoutModal extends ConsumerStatefulWidget {
  const CheckoutModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CheckoutModal(),
    );
  }

  @override
  ConsumerState<CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends ConsumerState<CheckoutModal> {
  String _selectedPaymentMethod = 'CASH';
  final TextEditingController _tenderedController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tenderedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _completeCheckout() async {
    final cart = ref.read(cartControllerProvider);
    if (cart.isEmpty) return;

    final tendered = double.tryParse(_tenderedController.text.trim()) ?? 0.0;
    if (_selectedPaymentMethod == 'CASH' && tendered < cart.grandTotalPreview) {
      setState(() {
        _errorMessage = 'Tendered amount must be at least \$${cart.grandTotalPreview.toStringAsFixed(2)}';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(salesRepositoryProvider);
      final sale = await repo.createSale(
        items: cart.items,
        paymentMethod: _selectedPaymentMethod,
        discountAmount: cart.discountAmount,
        taxAmount: cart.taxPreview,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      );

      // Refresh products and inventory states because stock was deducted by backend!
      ref.read(productsControllerProvider.notifier).refresh();
      ref.read(inventoryControllerProvider.notifier).loadAll();
      ref.read(salesHistoryControllerProvider.notifier).loadSales();

      if (mounted) {
        Navigator.of(context).pop(); // Close checkout modal

        // Clear cart
        ref.read(cartControllerProvider.notifier).clearCart();

        // Navigate to receipt
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReceiptScreen(saleId: sale.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ApiException.getErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = ref.watch(cartControllerProvider);
    final tendered = double.tryParse(_tenderedController.text.trim()) ?? 0.0;
    final change = tendered >= cart.grandTotalPreview ? tendered - cart.grandTotalPreview : 0.0;

    final errorMsg = _errorMessage;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Modal Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Complete Checkout',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space12),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorMsg != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.space12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 20, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMsg,
                              style: const TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space16),
                  ],

                  // Summary Card
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.space16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${cart.totalItemCount} Items Subtotal'),
                            Text('\$${cart.subtotalPreview.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                  if (cart.discountAmount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount', style: TextStyle(color: AppColors.inStock)),
                        Text('-\$${cart.discountAmount.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.inStock, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  if (cart.taxPreview > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated Tax'),
                        Text('+\$${cart.taxPreview.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total to Pay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '\$${cart.grandTotalPreview.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.space20),

            // Payment Methods
            const Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimensions.space12),

            Row(
              children: [
                _buildPaymentOption('CASH', Icons.payments_outlined, 'Cash'),
                const SizedBox(width: 8),
                _buildPaymentOption('CARD', Icons.credit_card, 'Card'),
                const SizedBox(width: 8),
                _buildPaymentOption('UPI', Icons.qr_code_2, 'UPI'),
                const SizedBox(width: 8),
                _buildPaymentOption('OTHER', Icons.more_horiz, 'Other'),
              ],
            ),
            const SizedBox(height: AppDimensions.space20),

            // Cash tendered and change calculation
            if (_selectedPaymentMethod == 'CASH') ...[
              AppTextField(
                label: 'Cash Tendered',
                hint: cart.grandTotalPreview.toStringAsFixed(2),
                controller: _tenderedController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.attach_money,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Quick Cash Preset Pills
              Wrap(
                spacing: 8,
                children: {
                  cart.grandTotalPreview,
                  (cart.grandTotalPreview / 10).ceil() * 10.0,
                  (cart.grandTotalPreview / 50).ceil() * 50.0,
                  (cart.grandTotalPreview / 100).ceil() * 100.0,
                }.where((v) => v >= cart.grandTotalPreview).map((val) {
                  return ActionChip(
                    label: Text('\$${val.toStringAsFixed(0)}'),
                    onPressed: () {
                      setState(() => _tenderedController.text = val.toStringAsFixed(2));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.space12),
                decoration: BoxDecoration(
                  color: AppColors.inStock.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.inStock.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Change Due:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '\$${change.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: AppColors.inStock,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.space16),
            ],

            // Note field
            AppTextField(
              label: 'Sale Note (Optional)',
              hint: 'e.g. Customer note, Table #4',
              controller: _noteController,
              prefixIcon: Icons.edit_note,
              maxLines: 2,
            ),
            const SizedBox(height: AppDimensions.space24),

            // Submit Button
            AppButton(
              text: 'Complete Sale (\$${cart.grandTotalPreview.toStringAsFixed(2)})',
              isLoading: _isLoading,
              onPressed: _completeCheckout,
            ),
          ],
        ),
      ),
    ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String code, IconData icon, String label) {
    final isSelected = _selectedPaymentMethod == code;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _selectedPaymentMethod = code;
          if (code == 'CASH') {
            final cart = ref.read(cartControllerProvider);
            _tenderedController.text = cart.grandTotalPreview.toStringAsFixed(2);
          }
        }),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: isSelected ? AppColors.accent : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.accent : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.accent : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

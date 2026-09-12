import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cart_controller.dart';
import '../../application/sales_history_controller.dart';
import '../../data/models/receipt_model.dart';
import '../../data/repositories/sales_repository.dart';

class ReceiptScreen extends ConsumerStatefulWidget {
  final String saleId;

  const ReceiptScreen({super.key, required this.saleId});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  ReceiptModel? _receipt;
  bool _isLoading = true;
  bool _isVoiding = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(salesRepositoryProvider);
      final r = await repo.getReceipt(widget.saleId);
      if (mounted) {
        setState(() {
          _receipt = r;
          _isLoading = false;
        });
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

  Future<void> _handleVoidSale() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Sale & Restore Inventory?'),
        content: const Text(
          'This will mark the sale as VOIDED, reverse all payments, '
          'and restore the deducted product quantities back to inventory atomically.\n\n'
          'Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Void Sale', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isVoiding = true);

    try {
      await ref.read(salesHistoryControllerProvider.notifier).voidSale(widget.saleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale successfully VOIDED. Inventory restored.'),
            backgroundColor: AppColors.inStock,
          ),
        );
        _loadReceipt();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to void sale: ${ApiException.getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isVoiding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);
    final isAuthorizedToVoid = authState.user?.isOwner == true || authState.user?.isManager == true;

    final errorMessage = _errorMessage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(cartControllerProvider.notifier).clearCart();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Loading transaction receipt...')
          : errorMessage != null
              ? ErrorStateView(
                  message: errorMessage,
                  onRetry: _loadReceipt,
                )
              : _buildReceiptCard(isDark, isAuthorizedToVoid),
    );
  }

  Widget _buildReceiptCard(bool isDark, bool isAuthorizedToVoid) {
    final r = _receipt;
    if (r == null) return const SizedBox.shrink();
    final s = r.sale;
    final isVoided = s.isVoided;
    final address = r.business.address;
    final phone = r.business.phone;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // Thermal Receipt Container
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  border: Border.all(
                    color: isVoided
                        ? AppColors.error.withValues(alpha: 0.5)
                        : (isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(AppDimensions.space24),
                child: Column(
                  children: [
                    // Void Stamp if VOIDED
                    if (isVoided) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              '*** VOIDED SALE ***',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Inventory Restored to Stock',
                              style: TextStyle(color: AppColors.error, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space16),
                    ],

                    // Business Header
                    Text(
                      r.business.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (address != null && address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    if (phone != null && phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Tel: $phone',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(thickness: 1),
                    const SizedBox(height: 8),

                    // Invoice Metadata
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Invoice: #${s.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(s.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s.createdAt?.toLocal().toString().split('.').first ?? '',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          'Cashier: ${s.cashierName ?? 'Staff'}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(thickness: 1),
                    const SizedBox(height: 8),

                    // Line Items
                    ...r.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  Text(
                                    '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '\$${item.totalPrice.toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                    const Divider(thickness: 1),
                    const SizedBox(height: 8),

                    // Totals Breakdown
                    _buildTotalRow('Subtotal', '\$${s.subtotal.toStringAsFixed(2)}'),
                    if (s.discountAmount > 0)
                      _buildTotalRow('Discount', '-\$${s.discountAmount.toStringAsFixed(2)}', isDiscount: true),
                    if (s.taxAmount > 0)
                      _buildTotalRow('Tax', '+\$${s.taxAmount.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    const Divider(thickness: 1.5),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '\$${s.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isVoided ? AppColors.error : AppColors.accent,
                            decoration: isVoided ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thank you for your business!',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.space24),

              // Bottom Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(cartControllerProvider.notifier).clearCart();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text('New Sale'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (s.isCompleted && isAuthorizedToVoid) ...[
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isVoiding ? null : _handleVoidSale,
                        icon: _isVoiding
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cancel_outlined, color: Colors.white),
                        label: Text(_isVoiding ? 'Voiding...' : 'Void Sale'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDiscount ? AppColors.inStock : null,
            ),
          ),
        ],
      ),
    );
  }
}


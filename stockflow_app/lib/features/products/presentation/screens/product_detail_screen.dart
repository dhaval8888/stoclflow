import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/products_controller.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/products_repository.dart';
import '../widgets/product_image_picker.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductModel? _product;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check in-memory list first for instant display
      final stateProducts = ref.read(productsControllerProvider).products;
      final match = stateProducts.where((p) => p.id == widget.productId);
      if (match.isNotEmpty) {
        if (mounted) {
          setState(() {
            _product = match.first;
            _isLoading = false;
          });
        }
        return;
      }

      // Fetch authoritative product details directly from repository (fixes deep-link/pagination bug)
      final fetched = await ref.read(productsRepositoryProvider).getProductById(widget.productId);
      if (mounted) {
        setState(() {
          _product = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiException.getErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDeactivate() async {
    final product = _product;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Product?'),
        content: Text(
          'Are you sure you want to deactivate "${product?.name ?? 'this product'}"? '
          'Inactive products are hidden from the POS register and cannot be sold, '
          'but remain in historical records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deactivate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(productsControllerProvider.notifier).deactivateProduct(widget.productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deactivated')),
          );
          _loadProduct();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiException.getErrorMessage(e))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);
    final isCashier = authState.user?.isCashier == true;

    ref.listen(productsControllerProvider, (prev, next) {
      final updated = next.products.where((p) => p.id == widget.productId);
      if (updated.isNotEmpty && mounted) {
        setState(() => _product = updated.first);
      }
    });

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: const LoadingView(message: 'Loading product details...'),
      );
    }

    if (_error != null || _product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: ErrorStateView(
          message: _error ?? 'Product not found',
          onRetry: _loadProduct,
        ),
      );
    }

    final p = _product;
    if (p == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!isCashier) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Product',
              onPressed: () async {
                final updated = await Navigator.of(context).push<ProductModel>(
                  MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)),
                );
                if (updated != null) {
                  setState(() => _product = updated);
                }
              },
            ),
            if (p.isActive)
              IconButton(
                icon: const Icon(Icons.visibility_off_outlined, color: AppColors.error),
                tooltip: 'Deactivate Product',
                onPressed: _confirmDeactivate,
              ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Gallery with uploader
            ProductImagePickerWidget(
              existingImages: p.images,
              readOnly: isCashier,
              onUpload: isCashier
                  ? null
                  : (file, onProgress) async {
                      await ref.read(productsControllerProvider.notifier).uploadProductImage(
                            p.id,
                            file,
                            onProgress: (sent, total) {
                              if (total > 0) onProgress(sent / total);
                            },
                          );
                    },
              onDelete: isCashier
                  ? null
                  : (imageId) async {
                      await ref.read(productsControllerProvider.notifier).deleteProductImage(p.id, imageId);
                    },
            ),
            const SizedBox(height: AppDimensions.space24),

            // Header card: Price & Stock status
            Container(
              padding: const EdgeInsets.all(AppDimensions.space16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selling Price',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${p.sellingPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: p.currentQuantity > p.lowStockThreshold
                          ? AppColors.inStock.withValues(alpha: 0.15)
                          : (p.currentQuantity > 0 ? AppColors.lowStock.withValues(alpha: 0.15) : AppColors.outOfStock.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${p.currentQuantity} ${p.unit}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: p.currentQuantity > p.lowStockThreshold
                                ? AppColors.inStock
                                : (p.currentQuantity > 0 ? AppColors.lowStock : AppColors.outOfStock),
                          ),
                        ),
                        Text(
                          p.currentQuantity > p.lowStockThreshold
                              ? 'In Stock'
                              : (p.currentQuantity > 0 ? 'Low Stock' : 'Out of Stock'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: p.currentQuantity > p.lowStockThreshold
                                ? AppColors.inStock
                                : (p.currentQuantity > 0 ? AppColors.lowStock : AppColors.outOfStock),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.space16),

            // SENSITIVE INFO CARD (Cost Price & Profit Margin) - Only for Owner / Manager / Admin!
            if (!isCashier && p.costPrice != null) ...[
              Container(
                padding: const EdgeInsets.all(AppDimensions.space16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, size: 16, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Confidential Cost & Margins (Owner/Manager Only)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Cost Price', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                '\$${p.costPrice!.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Profit per Unit', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                '\$${(p.sellingPrice - p.costPrice!).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.inStock,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (p.profitMargin != null)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Margin', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(
                                  '${p.profitMargin!.toStringAsFixed(1)}%',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.space16),
            ],

            // Specifications Card
            Container(
              padding: const EdgeInsets.all(AppDimensions.space16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Specifications',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const Divider(height: 20),
                  _buildSpecRow('Category', p.categoryName ?? 'Uncategorized', isDark),
                  _buildSpecRow('SKU', p.sku ?? 'None', isDark),
                  _buildSpecRow('Barcode', p.barcode ?? 'None', isDark),
                  _buildSpecRow('Unit of Measure', p.unit, isDark),
                  _buildSpecRow('Low Stock Alert', '${p.lowStockThreshold} ${p.unit}', isDark),
                  _buildSpecRow('Status', p.isActive ? 'Active' : 'Inactive (Deactivated)', isDark),
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    const Divider(height: 20),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(p.description!, style: const TextStyle(fontSize: 14)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

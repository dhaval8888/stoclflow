import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/barcode_scanner_modal.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../categories/application/categories_controller.dart';
import '../../../categories/presentation/widgets/category_dialog.dart';
import '../../application/products_controller.dart';
import '../../data/models/product_model.dart';
import '../widgets/product_image_picker.dart';
import '../../../inventory/data/models/inventory_item_model.dart';
import '../../../inventory/presentation/widgets/stock_movement_dialog.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final ProductModel? product;

  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _lowStockController;
  late final TextEditingController _initialStockController;

  String? _selectedCategoryId;
  String _selectedUnit = 'pcs';
  bool _isLoading = false;
  String? _errorMessage;

  static const List<String> _units = ['pcs', 'kg', 'ltr', 'gm', 'ml', 'box', 'dozen', 'pair'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    final initialCost = p?.costPrice;
    _costPriceController = TextEditingController(text: initialCost != null ? initialCost.toStringAsFixed(2) : '0.00');
    _sellingPriceController = TextEditingController(text: p != null ? p.sellingPrice.toStringAsFixed(2) : '');
    _lowStockController = TextEditingController(text: p != null ? p.lowStockThreshold.toString() : '10');
    _initialStockController = TextEditingController(text: '0');
    _selectedCategoryId = p?.categoryId;
    _selectedUnit = p?.unit ?? 'pcs';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _lowStockController.dispose();
    _initialStockController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerModal.show(context, title: 'Scan Barcode');
    if (code != null && code.isNotEmpty) {
      setState(() => _barcodeController.text = code);
    }
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final cost = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
    final sell = double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;
    final threshold = int.tryParse(_lowStockController.text.trim()) ?? 10;
    final initialStock = int.tryParse(_initialStockController.text.trim()) ?? 0;

    try {
      final controller = ref.read(productsControllerProvider.notifier);
      ProductModel saved;
      final existingProduct = widget.product;

      if (existingProduct == null) {
        saved = await controller.createProduct(
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          categoryId: _selectedCategoryId,
          sku: _skuController.text.trim(),
          barcode: _barcodeController.text.trim(),
          unit: _selectedUnit,
          costPrice: cost,
          sellingPrice: sell,
          lowStockThreshold: threshold,
          initialStock: initialStock,
        );
      } else {
        saved = await controller.updateProduct(
          existingProduct.id,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          categoryId: _selectedCategoryId,
          sku: _skuController.text.trim(),
          barcode: _barcodeController.text.trim(),
          unit: _selectedUnit,
          costPrice: cost,
          sellingPrice: sell,
          lowStockThreshold: threshold,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(saved);
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
    final isEdit = widget.product != null;
    final authState = ref.watch(authControllerProvider);
    final isCashier = authState.user?.isCashier == true;
    final categories = ref.watch(activeCategoriesProvider);
    final errorMsg = _errorMessage;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Product' : 'New Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Form(
          key: _formKey,
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

              // Product Images section (for existing product)
              if (isEdit && !isCashier) ...[
                ProductImagePickerWidget(
                  existingImages: widget.product?.images ?? [],
                  onUpload: (file, onProgress) async {
                    await ref.read(productsControllerProvider.notifier).uploadProductImage(
                          widget.product!.id,
                          file,
                          onProgress: (sent, total) {
                            if (total > 0) onProgress(sent / total);
                          },
                        );
                  },
                  onDelete: (imageId) async {
                    await ref.read(productsControllerProvider.notifier).deleteProductImage(
                          widget.product!.id,
                          imageId,
                        );
                  },
                ),
                const SizedBox(height: AppDimensions.space20),
              ],

              // Basic Info Section
              Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: AppDimensions.space12),

              AppTextField(
                label: 'Product Name',
                hint: 'e.g. Arabica Coffee Beans 250g',
                controller: _nameController,
                prefixIcon: Icons.inventory_2_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Product name is required' : null,
              ),
              const SizedBox(height: AppDimensions.space16),

              // Category dropdown + Add Category button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: const Icon(Icons.category_outlined, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                          borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                        ),
                      ),
                      hint: const Text('Select Category'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Uncategorized'),
                        ),
                        ...categories.map(
                          (c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () async {
                      final newCat = await CategoryDialog.show(context);
                      if (newCat != null) {
                        setState(() => _selectedCategoryId = newCat.id);
                      }
                    },
                    icon: const Icon(Icons.add),
                    tooltip: 'Add Category',
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space16),

              AppTextField(
                label: 'Description',
                hint: 'Optional product details and specs',
                controller: _descController,
                prefixIcon: Icons.notes,
                maxLines: 2,
              ),
              const SizedBox(height: AppDimensions.space20),

              // Barcode & SKU Section
              Text(
                'Identifiers & Unit',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: AppDimensions.space12),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Barcode',
                      hint: 'UPC / EAN code',
                      controller: _barcodeController,
                      prefixIcon: Icons.qr_code,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Scan Barcode',
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space16),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'SKU',
                      hint: 'e.g. COF-ARB-250',
                      controller: _skuController,
                      prefixIcon: Icons.tag,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                          borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                        ),
                      ),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUnit = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space20),

              // Pricing & Stock Threshold
              Text(
                'Pricing & Inventory Rules',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: AppDimensions.space12),

              Row(
                children: [
                  // Sensitive Cost Price: only shown to non-cashiers
                  if (!isCashier) ...[
                    Expanded(
                      child: AppTextField(
                        label: 'Cost Price',
                        hint: '0.00',
                        controller: _costPriceController,
                        prefixIcon: Icons.attach_money,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v.trim()) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                  ],

                  Expanded(
                    child: AppTextField(
                      label: 'Selling Price',
                      hint: '0.00',
                      controller: _sellingPriceController,
                      prefixIcon: Icons.payments_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final val = double.tryParse(v.trim());
                        if (val == null || val < 0) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space16),

              if (isEdit) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.space12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Available Stock', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.product?.currentQuantity ?? 0} ${widget.product?.unit ?? 'pcs'}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final item = InventoryItemModel(
                            id: widget.product!.id,
                            productId: widget.product!.id,
                            productName: widget.product!.name,
                            sku: widget.product!.sku,
                            currentQuantity: widget.product!.currentQuantity,
                            unit: widget.product!.unit,
                            lowStockThreshold: widget.product!.lowStockThreshold,
                            stockStatus: widget.product!.stockStatus,
                          );
                          final updated = await StockMovementDialog.show(context, item: item);
                          if (updated == true) {
                            ref.read(productsControllerProvider.notifier).refresh();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Stock updated successfully')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Adjust Stock'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space16),
                AppTextField(
                  label: 'Low Stock Alert Threshold',
                  hint: 'e.g. 10',
                  controller: _lowStockController,
                  prefixIcon: Icons.warning_amber_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (int.tryParse(v.trim()) == null) return 'Must be an integer';
                    return null;
                  },
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Initial Stock',
                        hint: 'e.g. 50',
                        controller: _initialStockController,
                        prefixIcon: Icons.inventory_2_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final val = int.tryParse(v.trim());
                          if (val == null || val < 0) return 'Must be >= 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: AppTextField(
                        label: 'Low Stock Threshold',
                        hint: 'e.g. 10',
                        controller: _lowStockController,
                        prefixIcon: Icons.warning_amber_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (int.tryParse(v.trim()) == null) return 'Must be an integer';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppDimensions.space24),

              AppButton(
                text: isEdit ? 'Save Product' : 'Create Product',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

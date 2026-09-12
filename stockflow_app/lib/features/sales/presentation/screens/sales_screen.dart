import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/barcode_scanner_modal.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../categories/application/categories_controller.dart';
import '../../../products/application/products_controller.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../../application/cart_controller.dart';
import '../../application/sales_history_controller.dart';
import '../widgets/checkout_modal.dart';
import 'receipt_screen.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final TabController _modeTabController;

  @override
  void initState() {
    super.initState();
    _modeTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _modeTabController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerModal.show(context, title: 'Scan Barcode to Add');
    if (code == null || code.isEmpty) return;

    final products = ref.read(productsControllerProvider).products;
    final match = products.where((p) => p.barcode == code || p.sku == code);

    if (match.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No active product found with code: $code'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final product = match.first;
    if (!product.isActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product is inactive and cannot be sold')),
        );
      }
      return;
    }

    if (product.currentQuantity <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} is currently out of stock'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    ref.read(cartControllerProvider.notifier).addProduct(product);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${product.name} to cart'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWideScreen = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode',
            onPressed: _scanBarcode,
          ),
        ],
        bottom: TabBar(
          controller: _modeTabController,
          tabs: const [
            Tab(text: 'POS Register'),
            Tab(text: 'Sales History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _modeTabController,
        children: [
          // Tab 1: POS Register
          isWideScreen ? _buildDualPane(isDark) : _buildMobileLayout(isDark),

          // Tab 2: Sales History
          _buildSalesHistoryTab(isDark),
        ],
      ),
    );
  }

  // ── Dual-Pane Layout (Tablet / Desktop) ──────────────────────────────────
  Widget _buildDualPane(bool isDark) {
    return Row(
      children: [
        // Left pane: Catalog & search
        Expanded(
          flex: 6,
          child: _buildProductCatalog(isDark),
        ),
        const VerticalDivider(width: 1),
        // Right pane: Persistent Cart
        Expanded(
          flex: 4,
          child: Container(
            color: isDark ? AppColors.surfaceElevatedDark.withValues(alpha: 0.5) : AppColors.surfaceElevatedLight.withValues(alpha: 0.5),
            child: _buildCartPanel(isDark, isEmbedded: true),
          ),
        ),
      ],
    );
  }

  // ── Mobile Layout ────────────────────────────────────────────────────────
  Widget _buildMobileLayout(bool isDark) {
    final cart = ref.watch(cartControllerProvider);

    return Stack(
      children: [
        _buildProductCatalog(isDark),

        // Floating Bottom Cart Bar if items exist
        if (!cart.isEmpty)
          Positioned(
            left: AppDimensions.space16,
            right: AppDimensions.space16,
            bottom: AppDimensions.space16,
            child: InkWell(
              onTap: () => _openMobileCartBottomSheet(context, isDark),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          '${cart.totalItemCount} ${cart.totalItemCount == 1 ? 'item' : 'items'}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '\$${cart.grandTotalPreview.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Product Catalog Section ──────────────────────────────────────────────
  Widget _buildProductCatalog(bool isDark) {
    final productsState = ref.watch(productsControllerProvider);
    final categories = ref.watch(activeCategoriesProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products by name or SKU...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(productsControllerProvider.notifier).onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => ref.read(productsControllerProvider.notifier).onSearchChanged(v),
                ),
                const SizedBox(height: 12),

                // Category chips
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: productsState.selectedCategoryId == null,
                        onSelected: (_) => ref.read(productsControllerProvider.notifier).onCategorySelected(null),
                      ),
                      const SizedBox(width: 8),
                      ...categories.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.name),
                            selected: productsState.selectedCategoryId == c.id,
                            onSelected: (sel) => ref
                                .read(productsControllerProvider.notifier)
                                .onCategorySelected(sel ? c.id : null),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Product Cards
        if (productsState.isInitialLoading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (productsState.products.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No active products match search')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = productsState.products[index];
                  if (!product.isActive) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.space12),
                    child: ProductCard(
                      product: product,
                      onTap: () => ref.read(cartControllerProvider.notifier).addProduct(product),
                      onAddToCart: () => ref.read(cartControllerProvider.notifier).addProduct(product),
                    ),
                  );
                },
                childCount: productsState.products.length,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  // ── Cart Panel ───────────────────────────────────────────────────────────
  Widget _buildCartPanel(bool isDark, {required bool isEmbedded}) {
    final cart = ref.watch(cartControllerProvider);

    return Column(
      children: [
        // Cart Header
        Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cart (${cart.totalItemCount})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (!cart.isEmpty)
                TextButton.icon(
                  onPressed: () => ref.read(cartControllerProvider.notifier).clearCart(),
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  label: const Text('Clear', style: TextStyle(color: AppColors.error)),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Cart Items List
        Expanded(
          child: cart.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Cart is empty', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 4),
                      Text('Tap items or scan barcode to add', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppDimensions.space16),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '\$${item.unitPrice.toStringAsFixed(2)} each',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),

                        // Stepper (- Qty +)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed: () => ref.read(cartControllerProvider.notifier).decrement(item.product.id),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                              Text(
                                '${item.quantity}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 16),
                                onPressed: () => ref.read(cartControllerProvider.notifier).increment(item.product.id),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Line Total
                        SizedBox(
                          width: 64,
                          child: Text(
                            '\$${item.lineTotal.toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),

        // Cart Totals & Checkout Button
        if (!cart.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppDimensions.space16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              border: Border(top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal Preview'),
                    Text('\$${cart.subtotalPreview.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 12),
                AppButton(
                  text: 'Charge \$${cart.grandTotalPreview.toStringAsFixed(2)}',
                  onPressed: () => CheckoutModal.show(context),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _openMobileCartBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: _buildCartPanel(isDark, isEmbedded: false),
      ),
    );
  }

  // ── Sales History Tab ────────────────────────────────────────────────────
  Widget _buildSalesHistoryTab(bool isDark) {
    final historyState = ref.watch(salesHistoryControllerProvider);

    if (historyState.isLoading) {
      return const LoadingView(message: 'Loading sales history...');
    }

    final errorMessage = historyState.errorMessage;
    if (errorMessage != null && historyState.sales.isEmpty) {
      return ErrorStateView(
        message: errorMessage,
        onRetry: () => ref.read(salesHistoryControllerProvider.notifier).loadSales(),
      );
    }

    if (historyState.sales.isEmpty) {
      return const EmptyStateView(
        title: 'No completed sales yet',
        subtitle: 'Completed sales transactions will appear here',
        icon: Icons.receipt_long_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(salesHistoryControllerProvider.notifier).loadSales(),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppDimensions.space16),
        itemCount: historyState.sales.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.space12),
        itemBuilder: (context, index) {
          final sale = historyState.sales[index];
          final isVoided = sale.isVoided;

          return InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ReceiptScreen(saleId: sale.id)),
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.space12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(
                  color: isVoided
                      ? AppColors.error.withValues(alpha: 0.4)
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isVoided
                          ? AppColors.error.withValues(alpha: 0.1)
                          : AppColors.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isVoided ? Icons.cancel_outlined : Icons.receipt_outlined,
                      color: isVoided ? AppColors.error : AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '#${sale.invoiceNumber}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isVoided
                                    ? AppColors.error.withValues(alpha: 0.15)
                                    : AppColors.inStock.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                sale.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isVoided ? AppColors.error : AppColors.inStock,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${sale.createdAt?.toLocal().toString().split('.').first ?? ''} • ${sale.paymentMethod}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${sale.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      decoration: isVoided ? TextDecoration.lineThrough : null,
                      color: isVoided ? Colors.grey : AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

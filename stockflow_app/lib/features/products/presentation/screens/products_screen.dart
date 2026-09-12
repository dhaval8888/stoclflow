import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/barcode_scanner_modal.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../categories/application/categories_controller.dart';
import '../../../categories/presentation/widgets/category_dialog.dart';
import '../../application/products_controller.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(productsControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerModal.show(context, title: 'Scan Product Barcode');
    if (code != null && code.isNotEmpty) {
      _searchController.text = code;
      ref.read(productsControllerProvider.notifier).onSearchChanged(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productsState = ref.watch(productsControllerProvider);
    final categories = ref.watch(activeCategoriesProvider);
    final authState = ref.watch(authControllerProvider);
    final isCashier = authState.user?.isCashier == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products & Catalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode',
            onPressed: _scanBarcode,
          ),
          if (!isCashier)
            IconButton(
              icon: const Icon(Icons.category_outlined),
              tooltip: 'New Category',
              onPressed: () => CategoryDialog.show(context),
            ),
        ],
      ),
      floatingActionButton: isCashier
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(productsControllerProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Search Bar & Filter Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.space16),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, SKU, or barcode...',
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
                    const SizedBox(height: AppDimensions.space12),

                    // Category Chips (Horizontal Scroll)
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            label: const Text('All Categories'),
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
                    const SizedBox(height: AppDimensions.space8),

                    // Stock Filter Chips
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildStockChip('All Stock', null, productsState.stockStatusFilter),
                          const SizedBox(width: 6),
                          _buildStockChip('In Stock', 'IN_STOCK', productsState.stockStatusFilter),
                          const SizedBox(width: 6),
                          _buildStockChip('Low Stock', 'LOW_STOCK', productsState.stockStatusFilter),
                          const SizedBox(width: 6),
                          _buildStockChip('Out of Stock', 'OUT_OF_STOCK', productsState.stockStatusFilter),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Product List or States
            if (productsState.isInitialLoading)
              const SliverFillRemaining(
                child: LoadingView(message: 'Loading products...'),
              )
            else if (productsState.hasError && productsState.products.isEmpty)
              SliverFillRemaining(
                child: ErrorStateView(
                  message: productsState.errorMessage ?? 'Failed to load products',
                  onRetry: () => ref.read(productsControllerProvider.notifier).loadInitial(),
                ),
              )
            else if (productsState.products.isEmpty)
              SliverFillRemaining(
                child: EmptyStateView(
                  title: 'No products found',
                  subtitle: 'Try adjusting your search or category filters',
                  icon: Icons.inventory_2_outlined,
                  actionText: !isCashier ? 'Add First Product' : null,
                  onAction: !isCashier
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ProductFormScreen()),
                          )
                      : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = productsState.products[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.space12),
                        child: ProductCard(
                          product: product,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(productId: product.id),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: productsState.products.length,
                  ),
                ),
              ),

            // Pagination Footer Indicators
            if (productsState.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppDimensions.space16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              )
            else if (productsState.hasPaginationError)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            productsState.paginationErrorMessage ?? 'Failed to load more items',
                            style: const TextStyle(fontSize: 12, color: AppColors.error),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => ref.read(productsControllerProvider.notifier).retryLoadMore(),
                          child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (productsState.hasMore && productsState.products.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: TextButton(
                      onPressed: () => ref.read(productsControllerProvider.notifier).loadMore(),
                      child: const Text('Load More'),
                    ),
                  ),
                ),
              )
            else if (!productsState.hasMore && productsState.products.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.space16),
                  child: Center(
                    child: Text(
                      'All ${productsState.total} products loaded',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildStockChip(String label, String? value, String? currentSelected) {
    final isSelected = currentSelected == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => ref.read(productsControllerProvider.notifier).onStockFilterSelected(value),
    );
  }
}

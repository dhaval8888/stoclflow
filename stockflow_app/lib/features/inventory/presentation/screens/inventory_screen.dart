import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/barcode_scanner_modal.dart';
import '../../../../core/widgets/state_views.dart';
import '../../application/inventory_controller.dart';
import '../widgets/stock_movement_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(inventoryControllerProvider.notifier).setTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerModal.show(context, title: 'Scan Barcode for Stock');
    if (code != null && code.isNotEmpty) {
      _searchController.text = code;
      ref.read(inventoryControllerProvider.notifier).onSearchChanged(code);
    }
  }

  Color _stockColor(String status) {
    switch (status) {
      case 'IN_STOCK':
        return AppColors.inStock;
      case 'LOW_STOCK':
        return AppColors.lowStock;
      case 'OUT_OF_STOCK':
      default:
        return AppColors.outOfStock;
    }
  }

  Color _txTypeColor(String type) {
    switch (type) {
      case 'STOCK_IN':
        return AppColors.inStock;
      case 'STOCK_OUT':
        return AppColors.lowStock;
      case 'ADJUSTMENT':
        return AppColors.accent;
      case 'SALE':
        return AppColors.primaryLight;
      case 'VOID_RETURN':
        return AppColors.info;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final invState = ref.watch(inventoryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Barcode',
            onPressed: _scanBarcode,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(inventoryControllerProvider.notifier).loadAll(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'All Items (${invState.totalItems})'),
            Tab(text: 'Low Stock (${invState.lowStockCount})'),
            Tab(text: 'Out of Stock (${invState.outOfStockCount})'),
            const Tab(text: 'Audit Log'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(inventoryControllerProvider.notifier).loadAll(),
        child: Column(
          children: [
            // Search field if not on Audit Log tab
            if (invState.selectedTab != 3)
              Padding(
                padding: const EdgeInsets.all(AppDimensions.space16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Filter by item name, SKU, or barcode...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(inventoryControllerProvider.notifier).onSearchChanged('');
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
                  onChanged: (v) => ref.read(inventoryControllerProvider.notifier).onSearchChanged(v),
                ),
              ),

            // Main Body Content
            Expanded(
              child: invState.isLoading
                  ? const LoadingView(message: 'Loading inventory data...')
                  : (invState.errorMessage != null && invState.items.isEmpty)
                      ? ErrorStateView(
                          message: invState.errorMessage!,
                          onRetry: () => ref.read(inventoryControllerProvider.notifier).loadAll(),
                        )
                      : (invState.selectedTab == 3
                          ? _buildAuditLogTab(invState, isDark)
                          : _buildInventoryList(invState, isDark)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryList(InventoryState invState, bool isDark) {
    final items = invState.filteredItems;

    if (items.isEmpty) {
      return EmptyStateView(
        title: invState.selectedTab == 1
            ? 'No low stock items'
            : (invState.selectedTab == 2 ? 'No out of stock items' : 'No items match your criteria'),
        subtitle: invState.selectedTab == 1
            ? 'All products are above their minimum threshold'
            : (invState.selectedTab == 2
                ? 'No items currently depleted'
                : 'Try adjusting your search query'),
        icon: Icons.inventory_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.space12),
      itemBuilder: (context, index) {
        final item = items[index];
        final statusColor = _stockColor(item.stockStatus);

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          padding: const EdgeInsets.all(AppDimensions.space12),
          child: Row(
            children: [
              // Quantity Badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${item.currentQuantity}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      item.unit,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.space12),

              // Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (item.sku != null && item.sku!.isNotEmpty) ...[
                          Text(
                            'SKU: ${item.sku}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          'Min: ${item.lowStockThreshold}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quick Action Buttons (Stock In, Stock Out, Adjust)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add, size: 18),
                    tooltip: 'Stock In',
                    onPressed: () => StockMovementDialog.show(context, item: item, initialType: 'STOCK_IN'),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove, size: 18),
                    tooltip: 'Stock Out',
                    onPressed: () => StockMovementDialog.show(context, item: item, initialType: 'STOCK_OUT'),
                  ),
                  const SizedBox(width: 4),
                  IconButton.outlined(
                    icon: const Icon(Icons.tune, size: 18),
                    tooltip: 'Physical Count Adjustment',
                    onPressed: () => StockMovementDialog.show(context, item: item, initialType: 'ADJUSTMENT'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuditLogTab(InventoryState invState, bool isDark) {
    final transactions = invState.transactions;

    if (transactions.isEmpty) {
      return const EmptyStateView(
        title: 'No transactions recorded yet',
        subtitle: 'Inventory movements and stock adjustments will appear here',
        icon: Icons.history_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.space16),
      itemCount: transactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.space12),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final typeColor = _txTypeColor(tx.type);
        final deltaText = tx.quantity >= 0 ? '+${tx.quantity}' : '${tx.quantity}';

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          padding: const EdgeInsets.all(AppDimensions.space12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tx.type == 'STOCK_IN'
                      ? Icons.arrow_downward
                      : (tx.type == 'STOCK_OUT'
                          ? Icons.arrow_upward
                          : (tx.type == 'SALE' ? Icons.shopping_bag_outlined : Icons.tune)),
                  size: 18,
                  color: typeColor,
                ),
              ),
              const SizedBox(width: AppDimensions.space12),

              // Transaction Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tx.productName ?? 'Product',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$deltaText ${tx.unit}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: tx.quantity >= 0 ? AppColors.inStock : AppColors.outOfStock,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tx.type,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                          ),
                        ),
                        Text(
                          'Before: ${tx.quantityBefore} -> After: ${tx.quantityAfter}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    if (tx.note != null && tx.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tx.note!,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    ],
                    if (tx.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${tx.createdAt!.toLocal().toString().split('.').first} • ${tx.userName ?? 'System'}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

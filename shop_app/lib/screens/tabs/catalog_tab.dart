import 'package:flutter/material.dart';
import '../../models.dart';
import '../../item_card.dart';
import '../../product_detail_screen.dart';
import '../../widgets/search_bar_widget.dart';

class CatalogTab extends StatefulWidget {
  final List<Product> products;
  final List<Product> shuffledProducts;
  final List<String> categories;
  final String repoUrl;
  final bool sendRetailPrice;
  final Map<String, int> cart;
  final void Function(int productId, {bool showSnackbar}) onAddToCart;
  final void Function(int productId) onRemoveFromCart;
  final Future<void> Function() onRefresh;

  const CatalogTab({
    super.key,
    required this.products,
    required this.shuffledProducts,
    required this.categories,
    required this.repoUrl,
    required this.sendRetailPrice,
    required this.cart,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.onRefresh,
  });

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Все';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var sourceList = _selectedCategory == 'Все'
        ? widget.shuffledProducts
        : widget.products;

    var filteredProducts = sourceList.where((p) {
      final matchesCategory =
          _selectedCategory == 'Все' || p.category == _selectedCategory;
      final matchesSearch =
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchBarWidget(
          controller: _searchController,
          hintText: 'Поиск товаров...',
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        if (widget.categories.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _buildCategoryPill(
                  label: 'Все',
                  isSelected: _selectedCategory == 'Все',
                  onTap: () => setState(() => _selectedCategory = 'Все'),
                ),
                ...widget.categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: _buildCategoryPill(
                      label: category,
                      isSelected: _selectedCategory == category,
                      onTap: () => setState(() => _selectedCategory = category),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: filteredProducts.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'Товары не найдены',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 120,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.44,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      final imageUrl = "${widget.repoUrl}/images/${product.image}";
                      final displayPrice = (widget.sendRetailPrice && product.retailPrice > 0)
                          ? product.retailPrice
                          : product.price;

                      return ItemCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(
                                product: product,
                                allProducts: widget.products,
                                getCartQuantity: (id) => widget.cart[id.toString()] ?? 0,
                                onIncrement: (id) => widget.onAddToCart(id, showSnackbar: true),
                                onDecrement: (id) => widget.onRemoveFromCart(id),
                              ),
                            ),
                          );
                        },
                        imageUrl: imageUrl,
                        placeholderIcon: Icons.shopping_bag,
                        title: product.name,
                        description: product.description,
                        priceText: '$displayPrice ₽',
                        pointsText: '${product.points} баллов',
                        cartQuantity: widget.cart[product.id.toString()] ?? 0,
                        onIncrement: () => widget.onAddToCart(product.id),
                        onDecrement: () => widget.onRemoveFromCart(product.id),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A);
    final inactiveBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inactiveText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeBg : borderColor,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A)).withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : inactiveText,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

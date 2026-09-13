import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ItemCard extends StatelessWidget {
  final VoidCallback onTap;
  final String imageUrl;
  final IconData placeholderIcon;
  final String title;
  final String description;
  final String? priceText;
  final String? pointsText;
  final int? cartQuantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const ItemCard({
    super.key,
    required this.onTap,
    required this.imageUrl,
    required this.placeholderIcon,
    required this.title,
    required this.description,
    this.priceText,
    this.pointsText,
    this.cartQuantity,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const SizedBox(
                        height: 160,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => const SizedBox(
                        height: 160,
                        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      ),
                    )
                  : SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: Icon(
                        placeholderIcon,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (priceText != null || pointsText != null) ...[
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            if (priceText != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                                        : const Color(0xFFBFDBFE),
                                  ),
                                ),
                                child: Text(
                                  priceText!,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF60A5FA)
                                        : const Color(0xFF2563EB),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            if (priceText != null && pointsText != null)
                              const SizedBox(width: 6),
                            if (pointsText != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF451A03).withValues(alpha: 0.3)
                                      : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                        : const Color(0xFFFDE68A),
                                  ),
                                ),
                                child: Text(
                                  pointsText!,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFFD97706),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      const SizedBox(height: 8),
                    ],
                    Expanded(
                      child: Text(
                        description,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (cartQuantity != null) ...[
                      const SizedBox(height: 10),
                      cartQuantity! > 0
                          ? Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF27272A)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF3F3F46)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove,
                                      size: 16,
                                    ),
                                    onPressed: onDecrement,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 38,
                                      minHeight: 38,
                                    ),
                                  ),
                                  Text(
                                    '$cartQuantity',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add,
                                      size: 16,
                                    ),
                                    onPressed: onIncrement,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 38,
                                      minHeight: 38,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox(
                              height: 38,
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? const Color(0xFFFAFAFA)
                                      : const Color(0xFF0F172A),
                                  foregroundColor: isDark
                                      ? const Color(0xFF09090B)
                                      : Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.add_shopping_cart, size: 16),
                                onPressed: onIncrement,
                                label: const Text(
                                  'В корзину',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

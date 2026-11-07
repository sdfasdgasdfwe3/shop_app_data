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
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final cardBg = Theme.of(context).cardColor;
    final cleanDesc = description.replaceAll(RegExp(r'\s+'), ' ').trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image Header
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Container(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        memCacheWidth: 350,
                        memCacheHeight: 350,
                        maxWidthDiskCache: 600,
                        maxHeightDiskCache: 600,
                        placeholder: (context, url) => const SizedBox(
                          height: 130,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => SizedBox(
                          height: 130,
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 130,
                        width: double.infinity,
                        child: Icon(
                          placeholderIcon,
                          size: 44,
                          color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                        ),
                      ),
              ),
            ),
            // Card Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                    if (cleanDesc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        cleanDesc,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.25,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const Spacer(),

                    // Price & Points Badges
                    if (priceText != null || pointsText != null) ...[
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (priceText != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                                        : const Color(0xFFBFDBFE),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  priceText!,
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (priceText != null && pointsText != null) const SizedBox(width: 6),
                            if (pointsText != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF451A03).withValues(alpha: 0.35)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                                        : const Color(0xFFFDE68A),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  pointsText!,
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    // Read more button for articles / reviews (when no cart or price)
                    if (cartQuantity == null && priceText == null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Подробнее',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                    ],

                    // Cart Buttons
                    if (cartQuantity != null) ...[
                      const SizedBox(height: 8),
                      cartQuantity! > 0
                          ? Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 16),
                                    onPressed: onDecrement,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                  ),
                                  Text(
                                    '$cartQuantity',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 16),
                                    onPressed: onIncrement,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
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
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
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

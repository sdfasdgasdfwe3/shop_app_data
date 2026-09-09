import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models.dart';

class PromoCardWidget extends StatelessWidget {
  final Product product;
  final String theme; // 'dark' / 'light'
  final String format; // 'square' / 'story'
  final String priceMode; // 'retail' / 'partner' / 'none'
  final String phone;
  final List<String> bullets;
  final String repoUrl;

  const PromoCardWidget({
    super.key,
    required this.product,
    required this.theme,
    required this.format,
    required this.priceMode,
    required this.phone,
    required this.bullets,
    required this.repoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme == 'dark';
    final isSquare = format == 'square';
    final contactPhone = phone.isNotEmpty ? phone : '+7 (999) 777-22-33';
    final imageUrl = "$repoUrl/images/${product.image}";
    final categoryName = product.category.toUpperCase();

    final bgDecoration = isDark
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const RadialGradient(
              center: Alignment(0.0, -0.4),
              radius: 1.1,
              colors: [
                Color(0xFF144535),
                Color(0xFF082017),
                Color(0xFF030D0A),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF34D399).withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF052E16).withValues(alpha: 0.6),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF0FDF4),
                Color(0xFFDCFCE7),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFA7F3D0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          );

    // Блок цены и баллов
    Widget priceSection;
    if (priceMode == 'retail' || priceMode == 'partner') {
      final isRetail = priceMode == 'retail';
      final priceVal = isRetail
          ? (product.retailPrice > 0 ? product.retailPrice : product.price)
          : product.price;
      final priceLabel = isRetail ? 'РОЗНИЧНАЯ ЦЕНА' : 'ПАРТНЕРСКАЯ ЦЕНА';

      final priceBg = isRetail
          ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFF059669))
          : (isDark ? const Color(0xFF10B981) : const Color(0xFF047857));

      final priceTextColor = isRetail
          ? (isDark ? const Color(0xFF0F172A) : Colors.white)
          : (isDark ? const Color(0xFF0F172A) : Colors.white);

      final priceSubColor = isRetail
          ? (isDark ? const Color(0xFF451A03) : const Color(0xFFD1FAE5))
          : (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5));

      final pointsBg = isDark ? const Color(0xFF0E382A) : const Color(0xFFF0FDF4);
      final pointsBorder = isDark
          ? const Color(0xFF34D399).withValues(alpha: 0.5)
          : const Color(0xFFA7F3D0);
      final pointsTextColor = isDark ? const Color(0xFFD1FAE5) : const Color(0xFF065F46);

      priceSection = IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Блок цены
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: priceBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$priceVal ₽',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: priceTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    priceLabel,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: priceSubColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Блок баллов
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: pointsBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pointsBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        '${product.points}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: pointsTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'БАЛЛОВ',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: pointsTextColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      priceSection = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF10B981).withValues(alpha: 0.2)
              : const Color(0xFF059669),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF34D399) : Colors.transparent,
          ),
        ),
        child: Text(
          '💬 Цена и консультация — в ЛС',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF6EE7B7) : Colors.white,
          ),
        ),
      );
    }

    if (isSquare) {
      // 1:1 КВАДРАТНЫЙ ПОСТ (400 x 400)
      return Container(
        width: 400,
        height: 400,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: bgDecoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Верхняя плашка
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0A231B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.all_inclusive,
                        size: 14,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'INFINITY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0E3024) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),

            // Средняя часть: Фото и тезисы
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0A221A) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF34D399).withValues(alpha: 0.5)
                          : const Color(0xFFA7F3D0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(6),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        errorWidget: (c, u, e) => const Icon(
                          Icons.shopping_bag,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...bullets.map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 13,
                                  color: isDark
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  b,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFD1FAE5)
                                        : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Блок цены (по центру)
            Center(child: priceSection),

            // Нижняя строка: контакты
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A291F)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E5B45)
                      : const Color(0xFFD1FAE5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone,
                    size: 15,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ЗАКАЗ И КОНСУЛЬТАЦИЯ: ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                    ),
                  ),
                  Text(
                    contactPhone,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // 9:16 ВЕРТИКАЛЬНАЯ СТОРИС (320 x 568)
      return Container(
        width: 320,
        height: 568,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: bgDecoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Верхняя плашка
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0A231B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.all_inclusive,
                        size: 15,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'INFINITY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0E3024) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),

            // Фото по центру
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A221A) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF34D399).withValues(alpha: 0.5)
                      : const Color(0xFFA7F3D0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.09),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (c, u, e) => const Icon(
                      Icons.shopping_bag,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),

            // Название товара
            Text(
              product.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),

            // Тезисы пользы
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF09251B).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E5B45)
                      : const Color(0xFFA7F3D0),
                ),
              ),
              child: Column(
                children: bullets.map((b) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Icon(
                            Icons.check_circle,
                            size: 13,
                            color: isDark
                                ? const Color(0xFF34D399)
                                : const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // Блок цены
            Center(child: priceSection),

            // Нижняя строка: контакты
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A291F)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E5B45)
                      : const Color(0xFFD1FAE5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone,
                    size: 15,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ЗАКАЗ И КОНСУЛЬТАЦИЯ: ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                    ),
                  ),
                  Text(
                    contactPhone,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}

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
    final isSquare = format == 'square';
    final contactPhone = phone.isNotEmpty ? phone : '+7 (999) 777-22-33';
    final imageUrl = "$repoUrl/images/${product.image}";
    final categoryName = product.category.toUpperCase();

    // Цветовая палитра темы
    final BoxDecoration bgDecoration;
    final Color primaryAccent;
    final Color brandBadgeBg;
    final Color brandBadgeBorder;
    final Color categoryBadgeBg;
    final Color categoryBadgeBorder;
    final Color categoryBadgeText;
    final Color photoFrameBg;
    final Color photoFrameBorder;
    final Color titleColor;
    final Color bulletsTextColor;
    final Color bulletIconColor;
    final Color bulletsBoxBg;
    final Color bulletsBoxBorder;
    final Color contactBoxBg;
    final Color contactBoxBorder;
    final Color contactLabelColor;
    final Color contactPhoneColor;
    final Color contactIconColor;

    switch (theme) {
      case 'blue': // Насыщенный синий
        bgDecoration = BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const RadialGradient(
            center: Alignment(0.0, -0.4),
            radius: 1.1,
            colors: [
              Color(0xFF13325B),
              Color(0xFF0C1F38),
              Color(0xFF050D18),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF031024).withValues(alpha: 0.65),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        );
        primaryAccent = const Color(0xFF38BDF8);
        brandBadgeBg = const Color(0xFF0B213D);
        brandBadgeBorder = const Color(0xFF38BDF8);
        categoryBadgeBg = const Color(0xFF0F2C52);
        categoryBadgeBorder = const Color(0xFF38BDF8).withValues(alpha: 0.4);
        categoryBadgeText = const Color(0xFFBAE6FD);
        photoFrameBg = const Color(0xFF0B213D);
        photoFrameBorder = const Color(0xFF38BDF8).withValues(alpha: 0.5);
        titleColor = Colors.white;
        bulletsTextColor = const Color(0xFFE0F2FE);
        bulletIconColor = const Color(0xFF38BDF8);
        bulletsBoxBg = const Color(0xFF0C1F38).withValues(alpha: 0.75);
        bulletsBoxBorder = const Color(0xFF1E3A8A);
        contactBoxBg = const Color(0xFF0B213D);
        contactBoxBorder = const Color(0xFF1E3A8A);
        contactLabelColor = const Color(0xFFBAE6FD);
        contactPhoneColor = Colors.white;
        contactIconColor = const Color(0xFF38BDF8);
        break;

      case 'sky': // Светло-голубой
        bgDecoration = BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF0F9FF),
              Color(0xFFE0F2FE),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF7DD3FC),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        );
        primaryAccent = const Color(0xFF0284C7);
        brandBadgeBg = Colors.white;
        brandBadgeBorder = const Color(0xFF0284C7);
        categoryBadgeBg = Colors.white;
        categoryBadgeBorder = const Color(0xFFBAE6FD);
        categoryBadgeText = const Color(0xFF0369A1);
        photoFrameBg = Colors.white;
        photoFrameBorder = const Color(0xFF7DD3FC);
        titleColor = const Color(0xFF0F172A);
        bulletsTextColor = const Color(0xFF1E293B);
        bulletIconColor = const Color(0xFF0284C7);
        bulletsBoxBg = Colors.white.withValues(alpha: 0.88);
        bulletsBoxBorder = const Color(0xFFBAE6FD);
        contactBoxBg = const Color(0xFFF0F9FF);
        contactBoxBorder = const Color(0xFFBAE6FD);
        contactLabelColor = const Color(0xFF0369A1);
        contactPhoneColor = const Color(0xFF0F172A);
        contactIconColor = const Color(0xFF0284C7);
        break;

      case 'light': // Эко-светлый
        bgDecoration = BoxDecoration(
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
        primaryAccent = const Color(0xFF059669);
        brandBadgeBg = Colors.white;
        brandBadgeBorder = const Color(0xFF10B981);
        categoryBadgeBg = Colors.white;
        categoryBadgeBorder = const Color(0xFFA7F3D0);
        categoryBadgeText = const Color(0xFF065F46);
        photoFrameBg = Colors.white;
        photoFrameBorder = const Color(0xFFA7F3D0);
        titleColor = const Color(0xFF0F172A);
        bulletsTextColor = const Color(0xFF334155);
        bulletIconColor = const Color(0xFF059669);
        bulletsBoxBg = Colors.white.withValues(alpha: 0.88);
        bulletsBoxBorder = const Color(0xFFA7F3D0);
        contactBoxBg = const Color(0xFFF0FDF4);
        contactBoxBorder = const Color(0xFFD1FAE5);
        contactLabelColor = const Color(0xFF065F46);
        contactPhoneColor = const Color(0xFF0F172A);
        contactIconColor = const Color(0xFF059669);
        break;

      case 'dark': // Изумрудный (по умолчанию темный)
      default:
        bgDecoration = BoxDecoration(
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
        );
        primaryAccent = const Color(0xFF34D399);
        brandBadgeBg = const Color(0xFF0A231B);
        brandBadgeBorder = const Color(0xFF34D399);
        categoryBadgeBg = const Color(0xFF0E3024);
        categoryBadgeBorder = const Color(0xFF10B981).withValues(alpha: 0.4);
        categoryBadgeText = const Color(0xFFA7F3D0);
        photoFrameBg = const Color(0xFF0A221A);
        photoFrameBorder = const Color(0xFF34D399).withValues(alpha: 0.5);
        titleColor = Colors.white;
        bulletsTextColor = const Color(0xFFD1FAE5);
        bulletIconColor = const Color(0xFF34D399);
        bulletsBoxBg = const Color(0xFF09251B).withValues(alpha: 0.7);
        bulletsBoxBorder = const Color(0xFF1E5B45);
        contactBoxBg = const Color(0xFF0A291F);
        contactBoxBorder = const Color(0xFF1E5B45);
        contactLabelColor = const Color(0xFFA7F3D0);
        contactPhoneColor = Colors.white;
        contactIconColor = const Color(0xFF34D399);
        break;
    }

    final isDarkTheme = theme == 'dark' || theme == 'blue';

    // Блок цены и баллов
    Widget priceSection;
    if (priceMode == 'retail' || priceMode == 'partner') {
      final isRetail = priceMode == 'retail';
      final priceVal = isRetail
          ? (product.retailPrice > 0 ? product.retailPrice : product.price)
          : product.price;
      final priceLabel = isRetail ? 'РОЗНИЧНАЯ ЦЕНА' : 'ПАРТНЕРСКАЯ ЦЕНА';

      Color priceBg;
      Color priceTextColor;
      Color priceSubColor;

      if (isRetail) {
        if (theme == 'sky') {
          priceBg = const Color(0xFFD97706);
          priceTextColor = Colors.white;
          priceSubColor = const Color(0xFFFEF3C7);
        } else if (theme == 'blue' || theme == 'dark') {
          priceBg = const Color(0xFFF59E0B);
          priceTextColor = const Color(0xFF0F172A);
          priceSubColor = const Color(0xFF451A03);
        } else {
          priceBg = const Color(0xFF059669);
          priceTextColor = Colors.white;
          priceSubColor = const Color(0xFFD1FAE5);
        }
      } else {
        // Партнерская
        if (theme == 'blue') {
          priceBg = const Color(0xFF2563EB);
          priceTextColor = Colors.white;
          priceSubColor = const Color(0xFFDBEAFE);
        } else if (theme == 'sky') {
          priceBg = const Color(0xFF0284C7);
          priceTextColor = Colors.white;
          priceSubColor = const Color(0xFFE0F2FE);
        } else if (theme == 'dark') {
          priceBg = const Color(0xFF10B981);
          priceTextColor = const Color(0xFF0F172A);
          priceSubColor = const Color(0xFF064E3B);
        } else {
          priceBg = const Color(0xFF047857);
          priceTextColor = Colors.white;
          priceSubColor = const Color(0xFFD1FAE5);
        }
      }

      Color pointsBg;
      Color pointsBorder;
      Color pointsTextColor;

      switch (theme) {
        case 'blue':
          pointsBg = const Color(0xFF0B213D);
          pointsBorder = const Color(0xFF38BDF8).withValues(alpha: 0.5);
          pointsTextColor = const Color(0xFFBAE6FD);
          break;
        case 'sky':
          pointsBg = const Color(0xFFF0F9FF);
          pointsBorder = const Color(0xFFBAE6FD);
          pointsTextColor = const Color(0xFF0369A1);
          break;
        case 'light':
          pointsBg = const Color(0xFFF0FDF4);
          pointsBorder = const Color(0xFFA7F3D0);
          pointsTextColor = const Color(0xFF065F46);
          break;
        case 'dark':
        default:
          pointsBg = const Color(0xFF0E382A);
          pointsBorder = const Color(0xFF34D399).withValues(alpha: 0.5);
          pointsTextColor = const Color(0xFFD1FAE5);
          break;
      }

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
      // Цена в ЛС
      Color noneBg;
      Color noneBorder;
      Color noneText;

      switch (theme) {
        case 'blue':
          noneBg = const Color(0xFF0284C7).withValues(alpha: 0.25);
          noneBorder = const Color(0xFF38BDF8);
          noneText = const Color(0xFF7DD3FC);
          break;
        case 'sky':
          noneBg = const Color(0xFF0284C7);
          noneBorder = Colors.transparent;
          noneText = Colors.white;
          break;
        case 'light':
          noneBg = const Color(0xFF059669);
          noneBorder = Colors.transparent;
          noneText = Colors.white;
          break;
        case 'dark':
        default:
          noneBg = const Color(0xFF10B981).withValues(alpha: 0.2);
          noneBorder = const Color(0xFF34D399);
          noneText = const Color(0xFF6EE7B7);
          break;
      }

      priceSection = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: noneBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: noneBorder),
        ),
        child: Text(
          '💬 Цена и консультация — в ЛС',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: noneText,
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
                    color: brandBadgeBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: brandBadgeBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.all_inclusive,
                        size: 14,
                        color: primaryAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'INFINITY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: primaryAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryBadgeBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: categoryBadgeBorder),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: categoryBadgeText,
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
                  width: 114,
                  height: 114,
                  decoration: BoxDecoration(
                    color: photoFrameBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: photoFrameBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDarkTheme ? 0.35 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => const Icon(
                        Icons.shopping_bag,
                        size: 40,
                        color: Colors.grey,
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
                          color: titleColor,
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
                                  color: bulletIconColor,
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
                                    color: bulletsTextColor,
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
                color: contactBoxBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: contactBoxBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone,
                    size: 15,
                    color: contactIconColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ЗАКАЗ И КОНСУЛЬТАЦИЯ: ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: contactLabelColor,
                    ),
                  ),
                  Text(
                    contactPhone,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: contactPhoneColor,
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
                    color: brandBadgeBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: brandBadgeBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.all_inclusive,
                        size: 15,
                        color: primaryAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'INFINITY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: primaryAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: categoryBadgeBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: categoryBadgeBorder),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: categoryBadgeText,
                    ),
                  ),
                ),
              ],
            ),

            // Фото по центру (широкоформатный контейнер 220 x 155 под пропорции студийных фото 1200x868)
            Container(
              width: 220,
              height: 155,
              decoration: BoxDecoration(
                color: photoFrameBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: photoFrameBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkTheme ? 0.35 : 0.09),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (c, u, e) => const Icon(
                    Icons.shopping_bag,
                    size: 50,
                    color: Colors.grey,
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
                color: titleColor,
              ),
            ),

            // Тезисы пользы
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bulletsBoxBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: bulletsBoxBorder),
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
                            color: bulletIconColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: bulletsTextColor,
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
                color: contactBoxBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: contactBoxBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone,
                    size: 15,
                    color: contactIconColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ЗАКАЗ И КОНСУЛЬТАЦИЯ: ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: contactLabelColor,
                    ),
                  ),
                  Text(
                    contactPhone,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: contactPhoneColor,
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

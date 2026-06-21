import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final List<Product> allProducts;
  final int Function(int) getCartQuantity;
  final void Function(int) onIncrement;
  final void Function(int) onDecrement;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.allProducts,
    required this.getCartQuantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const String _imageBaseUrl =
      "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/";

  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Widget> _parseSectionContent(
    String content,
    Color accentColor,
    BuildContext context,
  ) {
    final widgets = <Widget>[];
    final lines = content.split('\n');

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Списки с плюсом (+)
      if (trimmed.startsWith('+')) {
        final text = trimmed.substring(1).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Списки с минусом (-) или точкой (•)
      else if (trimmed.startsWith('-') || trimmed.startsWith('•')) {
        final text = trimmed.substring(1).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8.0),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Строки с двоеточием (например, "Компонент: Действие...")
      else if (trimmed.contains(':') &&
          trimmed.indexOf(':') > 2 &&
          trimmed.indexOf(':') < 40) {
        final colonIdx = trimmed.indexOf(':');
        final key = trimmed.substring(0, colonIdx).trim();
        final val = trimmed.substring(colonIdx + 1).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                children: [
                  TextSpan(
                    text: '$key: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: val),
                ],
              ),
            ),
          ),
        );
      }
      // Обычный текст
      else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              trimmed,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  List<ParsedSection> _parseDescription(
    String description,
    BuildContext context,
  ) {
    final sections = <ParsedSection>[];
    final lines = description.split('\n');

    String currentSectionType = 'info';

    List<String> infoLines = [];
    List<String> compositionLines = [];
    List<String> benefitsLines = [];
    List<String> usageLines = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final lower = trimmed.toLowerCase();

      if (lower.startsWith('состав:') ||
          lower.startsWith('активные компоненты:')) {
        currentSectionType = 'composition';
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx != -1 && colonIdx < trimmed.length - 1) {
          final remaining = trimmed.substring(colonIdx + 1).trim();
          if (remaining.isNotEmpty) compositionLines.add(remaining);
        }
      } else if (lower.startsWith('полезные свойства') ||
          lower.contains('полезные свойства компонентов') ||
          lower.startsWith('уже через')) {
        currentSectionType = 'benefits';
        if (lower.startsWith('полезные свойства')) {
          final colonIdx = trimmed.indexOf(':');
          if (colonIdx != -1 && colonIdx < trimmed.length - 1) {
            final remaining = trimmed.substring(colonIdx + 1).trim();
            if (remaining.isNotEmpty) benefitsLines.add(remaining);
          }
        } else {
          benefitsLines.add(line);
        }
      } else if (lower.startsWith('рекомендации по применению') ||
          lower.startsWith('способ применения')) {
        currentSectionType = 'usage';
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx != -1 && colonIdx < trimmed.length - 1) {
          final remaining = trimmed.substring(colonIdx + 1).trim();
          if (remaining.isNotEmpty) usageLines.add(remaining);
        }
      } else {
        if (currentSectionType == 'info') {
          infoLines.add(line);
        } else if (currentSectionType == 'composition') {
          compositionLines.add(line);
        } else if (currentSectionType == 'benefits') {
          benefitsLines.add(line);
        } else if (currentSectionType == 'usage') {
          usageLines.add(line);
        }
      }
    }

    if (infoLines.isNotEmpty) {
      sections.add(
        ParsedSection(
          title: 'Описание',
          icon: Icons.info_outline,
          color: const Color(0xFF3B82F6),
          textColor: const Color(0xFF1D4ED8),
          items: _parseSectionContent(
            infoLines.join('\n'),
            const Color(0xFF3B82F6),
            context,
          ),
        ),
      );
    }
    if (compositionLines.isNotEmpty) {
      sections.add(
        ParsedSection(
          title: 'Состав и активные компоненты',
          icon: Icons.spa_outlined,
          color: const Color(0xFF10B981),
          textColor: const Color(0xFF065F46),
          items: _parseSectionContent(
            compositionLines.join('\n'),
            const Color(0xFF10B981),
            context,
          ),
        ),
      );
    }
    if (benefitsLines.isNotEmpty) {
      sections.add(
        ParsedSection(
          title: 'Полезные свойства',
          icon: Icons.auto_awesome_outlined,
          color: const Color(0xFFF59E0B),
          textColor: const Color(0xFF92400E),
          items: _parseSectionContent(
            benefitsLines.join('\n'),
            const Color(0xFFF59E0B),
            context,
          ),
        ),
      );
    }
    if (usageLines.isNotEmpty) {
      sections.add(
        ParsedSection(
          title: 'Рекомендации по применению',
          icon: Icons.assignment_outlined,
          color: const Color(0xFF8B5CF6),
          textColor: const Color(0xFF5B21B6),
          items: _parseSectionContent(
            usageLines.join('\n'),
            const Color(0xFF8B5CF6),
            context,
          ),
        ),
      );
    }

    return sections;
  }

  Future<void> _shareProduct(
    BuildContext context,
    String imageUrl,
    String shareText,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Загрузка фото для отправки...'),
        duration: Duration(seconds: 1),
      ),
    );
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = await File(
          '${tempDir.path}/share_${widget.product.image}',
        ).create();
        await file.writeAsBytes(response.bodyBytes);

        if (!context.mounted) return;
        messenger.hideCurrentSnackBar();

        await Share.shareXFiles([XFile(file.path)], text: shareText);
      } else {
        throw Exception('Failed to load image');
      }
    } catch (e) {
      Share.share('$shareText\n\n🖼️ Фото: $imageUrl');
    }
  }

  Widget _buildAppBar(BuildContext context, String imageUrl, String shareText) {
    final double opacity = (_scrollOffset / 180.0).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final appBarBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final floatingIconBg =
        isDark
            ? Colors.black.withOpacity(0.4)
            : Colors.white.withOpacity(0.85);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 12,
          right: 12,
        ),
        height: kToolbarHeight + MediaQuery.of(context).padding.top,
        decoration: BoxDecoration(
          color: appBarBg.withOpacity(opacity),
          boxShadow:
              opacity > 0.1
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05 * opacity),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          children: [
            ClipOval(
              child: Material(
                color: Color.lerp(
                  floatingIconBg,
                  Colors.transparent,
                  opacity,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: iconColor,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Expanded(
              child: Opacity(
                opacity: opacity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    widget.product.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            ),
            ClipOval(
              child: Material(
                color: Color.lerp(
                  floatingIconBg,
                  Colors.transparent,
                  opacity,
                ),
                child: IconButton(
                  icon: const Icon(Icons.share),
                  color: iconColor,
                  onPressed:
                      () => _shareProduct(context, imageUrl, shareText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadges(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_offer_outlined,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.product.price} ₽',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.orange.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                '${widget.product.points} баллов',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(ParsedSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: section.color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: section.color.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: section.color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(section.icon, color: section.color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: section.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: section.items,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarProducts(List<Product> similarProducts) {
    if (similarProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Text(
            'Похожие товары',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: similarProducts.length,
            itemBuilder: (context, index) {
              final similar = similarProducts[index];
              final simImageUrl = "$_imageBaseUrl${similar.image}";
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ProductDetailScreen(
                            product: similar,
                            allProducts: widget.allProducts,
                            getCartQuantity: widget.getCartQuantity,
                            onIncrement: widget.onIncrement,
                            onDecrement: widget.onDecrement,
                          ),
                    ),
                  ).then((_) {
                    setState(() {});
                  });
                },
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.12),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: simImageUrl,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) => Container(
                                  color: Colors.grey.shade100,
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              similar.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${similar.price} ₽',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final int qty = widget.getCartQuantity(widget.product.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          if (qty > 0) ...[
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(27),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.blue),
                    onPressed: () {
                      widget.onDecrement(widget.product.id);
                      setState(() {});
                    },
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 32),
                    alignment: Alignment.center,
                    child: Text(
                      '$qty',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.blue),
                    onPressed: () {
                      widget.onIncrement(widget.product.id);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text(
                    'В корзине',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Товар уже в корзине!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text(
                    'Добавить в корзину',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    widget.onIncrement(widget.product.id);
                    setState(() {});
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final similarProducts =
        widget.allProducts
            .where(
              (p) =>
                  p.category == widget.product.category &&
                  p.id != widget.product.id,
            )
            .toList();

    final imageUrl = "$_imageBaseUrl${widget.product.image}";
    final shareText =
        '📦 ${widget.product.name}\n💰 Цена: ${widget.product.price} ₽\n⭐ Баллы: ${widget.product.points}\n\n📝 Описание:\n${widget.product.description}';

    final parsedSections = _parseDescription(
      widget.product.description,
      context,
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'product_image_${widget.product.id}',
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      height: 380,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => Container(
                            height: 380,
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            height: 380,
                            color: Colors.grey.shade100,
                            child: const Icon(
                              Icons.broken_image,
                              size: 80,
                              color: Colors.grey,
                            ),
                          ),
                    ),
                  ),
                  Container(
                    transform: Matrix4.translationValues(0, -28, 0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Center(
                            child: Text(
                              widget.product.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(child: _buildBadges(context)),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                parsedSections
                                    .map((s) => _buildSectionCard(s))
                                    .toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSimilarProducts(similarProducts),
                        SizedBox(
                          height: 80 + MediaQuery.of(context).padding.bottom,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildAppBar(context, imageUrl, shareText),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }
}

class ParsedSection {
  final String title;
  final List<Widget> items;
  final IconData icon;
  final Color color;
  final Color textColor;

  ParsedSection({
    required this.title,
    required this.items,
    required this.icon,
    required this.color,
    required this.textColor,
  });
}

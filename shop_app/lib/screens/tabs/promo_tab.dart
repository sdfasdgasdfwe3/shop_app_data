import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models.dart';
import '../../widgets/promo_card_widget.dart';

class PromoTab extends StatefulWidget {
  final AppData appData;
  final String repoUrl;

  const PromoTab({
    super.key,
    required this.appData,
    required this.repoUrl,
  });

  @override
  State<PromoTab> createState() => _PromoTabState();
}

class _PromoTabState extends State<PromoTab> {
  final TextEditingController _promoPhoneController = TextEditingController();
  Product? _selectedPromoProduct;
  String _promoFormat = 'square'; // 'square' (1:1), 'story' (9:16)
  String _promoTheme = 'dark'; // 'dark' (Изумруд), 'light' (Эко)
  String _promoPriceMode = 'retail'; // 'retail' (Розничная цена), 'partner', 'none'
  final GlobalKey _promoRepaintKey = GlobalKey();
  bool _isExportingPromo = false;

  @override
  void initState() {
    super.initState();
    _loadPromoSettings();
  }

  @override
  void dispose() {
    _promoPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadPromoSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _promoPhoneController.text =
              prefs.getString('custom_promo_phone') ?? '';
          _promoFormat = prefs.getString('custom_promo_format') ?? 'square';
          _promoTheme = prefs.getString('custom_promo_theme') ?? 'dark';
          _promoPriceMode =
              prefs.getString('custom_promo_price_mode') ?? 'retail';
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки настроек промо: $e');
    }
  }

  Future<void> _savePromoSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_promo_phone', _promoPhoneController.text);
      await prefs.setString('custom_promo_format', _promoFormat);
      await prefs.setString('custom_promo_theme', _promoTheme);
      await prefs.setString('custom_promo_price_mode', _promoPriceMode);
    } catch (e) {
      debugPrint('Ошибка сохранения промо-настроек: $e');
    }
  }

  List<String> _extractPromoBullets(Product product) {
    final desc = product.description;
    final lines = desc
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Поиск явного раздела «Полезные свойства» / «Влияние на организм» / «Действие»
    List<String> benefitsLines = [];
    bool inBenefits = false;

    for (var l in lines) {
      final lower = l.toLowerCase();

      // Начало блока полезных свойств
      if (lower.startsWith('полезные свойства') ||
          lower.startsWith('влияние на организм') ||
          lower.startsWith('основное действие') ||
          lower.startsWith('действие:') ||
          lower.startsWith('действие продукта') ||
          lower.startsWith('основные свойства') ||
          lower.startsWith('свойства продукта') ||
          lower.startsWith('свойства:') ||
          lower.startsWith('уже через')) {
        inBenefits = true;
        final colonIdx = l.indexOf(':');
        if (colonIdx != -1 && colonIdx < l.length - 1) {
          final after = l.substring(colonIdx + 1).trim();
          if (after.length > 10) {
            benefitsLines.add(after);
          }
        }
        continue;
      }

      if (inBenefits) {
        // Конец блока полезных свойств при переходе к другому разделу
        if (lower.startsWith('состав:') ||
            lower.startsWith('состав') ||
            lower.startsWith('способ применения') ||
            lower.startsWith('рекомендации') ||
            lower.startsWith('противопоказания') ||
            lower.startsWith('условия хранения') ||
            lower.startsWith('срок годности') ||
            lower.startsWith('форма выпуска') ||
            lower.startsWith('масса') ||
            lower.startsWith('объем') ||
            lower.startsWith('курс') ||
            (l.endsWith(':') &&
                !lower.contains('свойств') &&
                !lower.contains('действи') &&
                !lower.contains('организм') &&
                !lower.contains('эффект'))) {
          inBenefits = false;
          continue;
        }
        benefitsLines.add(l);
      }
    }

    // 2. Если отдельного блока свойств не найдено, берем строки описания,
    // строго исключая блок «Состав:» и служебные инструкции
    List<String> candidateLines = [];
    if (benefitsLines.isNotEmpty) {
      candidateLines = benefitsLines;
    } else {
      bool skipBlock = false;
      for (var l in lines) {
        final lower = l.toLowerCase();
        if (lower.startsWith('состав:') ||
            lower.startsWith('состав') ||
            lower.startsWith('активные компоненты:')) {
          skipBlock = true;
          continue;
        }
        if (skipBlock) {
          if (lower.startsWith('способ применения') ||
              lower.startsWith('рекомендации') ||
              lower.startsWith('противопоказания') ||
              lower.startsWith('условия хранения') ||
              lower.startsWith('срок годности') ||
              lower.startsWith('форма выпуска') ||
              lower.startsWith('показания') ||
              lower.startsWith('действие') ||
              l.endsWith(':')) {
            skipBlock = false;
          } else {
            continue;
          }
        }
        if (lower.startsWith('способ применения') ||
            lower.startsWith('противопоказания') ||
            lower.startsWith('условия хранения') ||
            lower.startsWith('срок годности') ||
            lower.startsWith('форма выпуска') ||
            lower.startsWith('масса') ||
            lower.startsWith('объем') ||
            lower.startsWith('курс') ||
            lower.startsWith('пищевая ценность')) {
          continue;
        }
        candidateLines.add(l);
      }
    }

    // 3. Формирование кратких и понятных тезисов
    List<String> bullets = [];

    for (var raw in candidateLines) {
      String l = raw.trim();
      l = l.replaceAll(RegExp(r'^[•\-\+«\*\d\.\)\s]+'), '').trim();
      l = l.replaceAll('«', '').replaceAll('»', '').replaceAll('"', '');
      l = l
          .replaceAll(
            RegExp(
              r'^(Крем Ведария|Сироп|Чайный напиток|Фитосбор|БАЛАНС ИНФИНИТИ|СУСТАКАПС|ИММУНОКАПС|ДИАБЕТУ НЕТ|АНДРОКАПС|РЕЛАКС|КАРДИОКАПС|БРОНХОКАПС)\s*(\d+\s*шт|\d+\s*капс|\d+\s*мл|\d+\s*г)?\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();

      final lLower = l.toLowerCase();
      if (lLower.startsWith('полезные свойства') ||
          lLower.startsWith('влияние на организм') ||
          lLower.startsWith('уже через') ||
          lLower.startsWith('состав') ||
          l.endsWith(':') ||
          l.length < 10) {
        continue;
      }

      // Разбиваем по точкам, восклицательным знакам или точкам с запятой
      final parts = l.split(RegExp(r'(?<=[.;!])\s+|\s*;\s*'));
      for (var rawPart in parts) {
        String s = rawPart.trim();
        s = s.replaceAll(RegExp(r'^[•\-\+«\*\d\.\)\s]+'), '').trim();
        s = s.replaceAll(RegExp(r'[.;!]+$'), '').trim();

        if (s.length < 10) continue;

        final sLower = s.toLowerCase();
        if (sLower.contains('хранить') ||
            sLower.contains('годен') ||
            sLower.contains('курс приема') ||
            sLower.contains('противопоказан') ||
            sLower.contains('в сухом месте') ||
            sLower.contains('внутрь') ||
            sLower.contains('способ применения') ||
            sLower.contains('детям до') ||
            sLower.contains('беременн') ||
            sLower.contains('по 1 капсул') ||
            sLower.contains('по 2 капсул') ||
            sLower.contains('до еды') ||
            sLower.contains('после еды') ||
            sLower.contains('во время еды')) {
          continue;
        }

        // Если строка вида "Компонент — Действие" или "Компонент: Действие"
        if (s.contains('—')) {
          final sub = s.split('—');
          String action = sub[1].trim();
          if (action.contains(':')) {
            action = action.split(':')[1].trim();
          }
          if (action.length >= 12) s = action;
        } else if (s.contains(' - ')) {
          final sub = s.split(' - ');
          String action = sub[1].trim();
          if (action.contains(':')) {
            action = action.split(':')[1].trim();
          }
          if (action.length >= 12) s = action;
        } else if (s.contains(':') && !s.startsWith('http')) {
          final sub = s.split(':');
          String action = sub[1].trim();
          if (action.length >= 12) s = action;
        }

        // Очищаем вводные слова в начале
        s = s
            .replaceAll(
              RegExp(
                r'^(который|которая|которое|которые|что|он|она|оно|они|также он|также она|также оно|также они|также|кроме того|за счет этого|благодаря этому|при этом)\s+',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
        s = s
            .replaceAll(
              RegExp(
                r'^(положительно влияет на [^:,;]+:\s*)',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
        s = s
            .replaceAll(
              RegExp(
                r'^(положительно влияет на [^:,;]+,\s*)',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
        s = s
            .replaceAll(
              RegExp(
                r'^(100%|натуральный природный|природный)\s+',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
        s = s.replaceAll('дает мощный', 'Обеспечивает');
        s = s.replaceAll(
          'самый насыщенный и комплексный по составу крем, который является эффективным средством, как при',
          'Эффективен при',
        );
        s = s.replaceAll(
          'является эффективным средством, как при',
          'Эффективен при',
        );
        s = s.replaceAll('является эффективным средством при', 'Эффективен при');

        // Первая буква заглавная
        if (s.isNotEmpty && s[0].toLowerCase() == s[0]) {
          s = s[0].toUpperCase() + s.substring(1);
        }

        // Если слишком длинно, укорачиваем до первой запятой
        if (s.length > 52 && s.contains(',')) {
          final cp = s.split(',');
          if (cp[0].trim().length >= 15) {
            s = cp[0].trim();
          }
        }

        if (s.length >= 12 && s.length <= 56 && !bullets.contains(s)) {
          bullets.add(s);
        }
        if (bullets.length >= 3) break;
      }
      if (bullets.length >= 3) break;
    }

    // Резервный вариант, если найдено меньше 3
    if (bullets.length < 3) {
      for (var raw in lines) {
        final lower = raw.toLowerCase();
        if (lower.startsWith('состав') ||
            lower.startsWith('хранить') ||
            lower.startsWith('годен') ||
            lower.startsWith('противопоказан') ||
            lower.startsWith('способ')) {
          continue;
        }
        String s =
            raw.replaceAll(RegExp(r'^[•\-\+«\*\d\.\)\s]+'), '').trim();
        s = s.replaceAll(RegExp(r'[.;!]+$'), '').trim();
        if (s.contains(',') && s.length > 50) {
          s = s.split(',')[0].trim();
        }
        if (s.length >= 12 && s.length <= 56 && !bullets.contains(s)) {
          bullets.add(s);
        }
        if (bullets.length >= 3) break;
      }
    }

    return bullets.take(3).toList();
  }

  Future<void> _exportAndSharePromoCard() async {
    if (_isExportingPromo) return;
    setState(() => _isExportingPromo = true);

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _promoRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('RenderRepaintBoundary не найден');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Не удалось закодировать изображение в PNG');
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final product = _selectedPromoProduct ??
          (widget.appData.products.isNotEmpty
              ? widget.appData.products.first
              : null);
      final prodName = product?.name ?? 'INFINITY';
      final bullets = product != null ? _extractPromoBullets(product) : <String>[];

      final StringBuffer sb = StringBuffer();
      sb.writeln('✨ $prodName\n');

      if (bullets.isNotEmpty) {
        sb.writeln('🌿 Полезные свойства:');
        for (var b in bullets) {
          sb.writeln('• $b');
        }
        sb.writeln();
      }

      if (_promoPriceMode == 'retail') {
        final priceVal = product != null && product.retailPrice > 0
            ? product.retailPrice
            : product?.price ?? 0;
        sb.writeln('💰 Розничная цена: $priceVal ₽\n');
      } else if (_promoPriceMode == 'partner') {
        final priceVal = product?.price ?? 0;
        sb.writeln('💰 Партнерская цена: $priceVal ₽\n');
      }

      final phone = _promoPhoneController.text.isNotEmpty
          ? _promoPhoneController.text
          : '+7 (999) 777-22-33';
      sb.write('📞 Заказ и консультация: $phone');

      final shareText = sb.toString();

      if (kIsWeb) {
        final xFile = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'promo_${product?.id ?? 0}.png',
        );
        await Share.shareXFiles([xFile], text: shareText);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/promo_${product?.id ?? 0}_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);
        final xFile = XFile(
          file.path,
          mimeType: 'image/png',
          name: 'promo_${product?.id ?? 0}.png',
        );
        await Share.shareXFiles([xFile], text: shareText);
      }
    } catch (e) {
      debugPrint('Ошибка при создании промо-карточки: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания карточки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPromo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.appData.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    _selectedPromoProduct ??= widget.appData.products.first;
    final product = _selectedPromoProduct!;

    return SingleChildScrollView(
      padding:
          const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Карточка 1: Личные контакты дистрибьютора
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.badge_outlined, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Контакты для заказа и консультации',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _promoPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Ваш номер телефона для заказа и консультации',
                      hintText: '+7 (999) 777-22-33',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _savePromoSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Карточка 2: Параметры карточки
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Параметры карточки',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Выбор продукта
                  const Text(
                    'Выберите продукт:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Product>(
                    initialValue: _selectedPromoProduct,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    items: widget.appData.products.map((p) {
                      return DropdownMenuItem<Product>(
                        value: p,
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (newProduct) {
                      if (newProduct != null) {
                        setState(() {
                          _selectedPromoProduct = newProduct;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Выбор формата (размера)
                  const Text(
                    'Размер карточки:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('1:1 Пост')),
                          selected: _promoFormat == 'square',
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color:
                                _promoFormat == 'square' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoFormat = 'square');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('9:16 Сторис')),
                          selected: _promoFormat == 'story',
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color:
                                _promoFormat == 'story' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoFormat = 'story');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Выбор стиля
                  const Text(
                    'Стиль оформления:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('🌲 Изумрудный')),
                          selected: _promoTheme == 'dark',
                          selectedColor: const Color(0xFF065F46),
                          labelStyle: TextStyle(
                            color: _promoTheme == 'dark' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoTheme = 'dark');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('🕊️ Эко-светлый')),
                          selected: _promoTheme == 'light',
                          selectedColor: Colors.teal.shade700,
                          labelStyle: TextStyle(
                            color: _promoTheme == 'light' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoTheme = 'light');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Выбор отображения цены
                  const Text(
                    'Отображение цены:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Розничная цена'),
                          selected: _promoPriceMode == 'retail',
                          selectedColor: const Color(0xFFF59E0B),
                          labelStyle: TextStyle(
                            color: _promoPriceMode == 'retail'
                                ? const Color(0xFF0F172A)
                                : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoPriceMode = 'retail');
                              _savePromoSettings();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Партнерская'),
                          selected: _promoPriceMode == 'partner',
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: _promoPriceMode == 'partner'
                                ? Colors.white
                                : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoPriceMode = 'partner');
                              _savePromoSettings();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Без цены («в ЛС»)'),
                          selected: _promoPriceMode == 'none',
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: _promoPriceMode == 'none'
                                ? Colors.white
                                : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoPriceMode = 'none');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Заголовок предпросмотра
          const Center(
            child: Text(
              'Предпросмотр карточки',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // Контейнер предпросмотра с RepaintBoundary
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RepaintBoundary(
                key: _promoRepaintKey,
                child: PromoCardWidget(
                  product: product,
                  theme: _promoTheme,
                  format: _promoFormat,
                  priceMode: _promoPriceMode,
                  phone: _promoPhoneController.text,
                  bullets: _extractPromoBullets(product),
                  repoUrl: widget.repoUrl,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Кнопка экспорта / отправки
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              onPressed: _isExportingPromo ? null : _exportAndSharePromoCard,
              icon: _isExportingPromo
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.share, size: 22),
              label: Text(
                _isExportingPromo
                    ? 'Формирование изображения...'
                    : 'Поделиться промо-карточкой',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

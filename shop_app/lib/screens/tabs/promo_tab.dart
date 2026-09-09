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
    const benefitRoots = [
      'улучш', 'повыш', 'укрепл', 'восстановл', 'нормализ', 'защищ',
      'очищ', 'снимает', 'сняти', 'эффективен', 'стимулир', 'поддержив',
      'поддержк', 'предотвращ', 'помога', 'насыщ', 'купир', 'заживл',
      'устраня', 'активизир', 'снижа', 'снижени', 'облегча', 'тонизир',
      'успокаив', 'омолажив', 'антиоксидант', 'противовоспалительн',
      'противовирусн', 'седативн', 'благотворн', 'благоприятн', 'увеличива',
      'уничтожа', 'обезболивающ', 'замедляет старение', 'оздоравлива',
      'борется', 'кровоостанавливающ', 'регенерирующ', 'бактерицидн'
    ];

    const nonBenefitWords = [
      'содержит', 'в состав', 'богат', 'богаты', 'имеют богатый состав', 'обнаружены',
      'присутствуют', 'хранить', 'годен', 'курс приема', 'противопоказан',
      'внутрь', 'в сухом', 'капсул', 'до еды',
      'во время еды', 'после еды', 'масса', 'объем', 'форма выпуска', 'является продуктом',
      'изготовлен', 'произрастает', 'при хранении', 'за счет него',
      'полезные свойства', 'описание свойств', 'влияние на организм',
      'свойства продукта', 'состав:'
    ];

    const hangingEndings = [
      'ого', 'его', 'ому', 'ему', 'ым', 'им', 'ом', 'ем', 'ой', 'ей',
      'ую', 'юю', 'ых', 'их', 'ыми', 'ими', 'ое', 'ее', 'ая', 'яя',
      'ый', 'ий'
    ];

    const hangingPrepositions = [
      'в', 'на', 'от', 'к', 'до', 'по', 'из', 'при', 'как', 'для',
      'не только', 'в том числе', 'что', 'чем', 'а', 'и', 'или', 'но', 'с'
    ];

    const exemptNouns = {
      'настроение', 'давление', 'кровообращение', 'пищеварение', 'состояние',
      'действие', 'внимание', 'дыхание', 'зрение', 'здоровье', 'долголетие'
    };

    bool hasBenefit(String text) {
      final tl = text.toLowerCase();
      return benefitRoots.any((r) => tl.contains(r));
    }

    bool isGrammaticallyIncomplete(String s) {
      final sl = s.toLowerCase().trim();
      if (sl.endsWith(':') || sl.endsWith(',') || sl.endsWith('-') || sl.endsWith('—')) {
        return true;
      }
      final words = sl.split(RegExp(r'\s+'));
      if (words.isEmpty) return true;
      final lastWord = words.last;
      final lastWordClean = lastWord.replaceAll(RegExp(r'[^а-яё]'), '');

      if (hangingPrepositions.contains(lastWordClean)) {
        return true;
      }
      if (exemptNouns.contains(lastWordClean)) {
        return false;
      }
      if (lastWordClean.length >= 4 &&
          hangingEndings.any((e) => lastWordClean.endsWith(e))) {
        return true;
      }
      return false;
    }

    String cleanClause(String s) {
      var res = s.trim();
      res = res.replaceAll(RegExp(r'^[•\-\+«\*\d\.\)\s]+'), '').trim();
      res = res.replaceAll('«', '').replaceAll('»', '').replaceAll('"', '');
      if (res.contains('(') && !res.contains(')')) {
        res = res.split('(')[0].trim();
      }
      res = res.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
      res = res
          .replaceAll(
            RegExp(
              r'^(Крем Ведария|Сироп|Чайный напиток|Фитосбор|БАЛАНС ИНФИНИТИ|СУСТАКАПС|ИММУНОКАПС|ДИАБЕТУ НЕТ|АНДРОКАПС|РЕЛАКС|КАРДИОКАПС|БРОНХОКАПС)\s*(\d+\s*шт|\d+\s*капс|\d+\s*мл|\d+\s*г)?\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      res = res
          .replaceAll(
            RegExp(
              r'^(который|которая|которое|которые|что|он|она|оно|они|также он|также она|также оно|также они|также|кроме того|за счет этого|благодаря этому|при этом|в итоге|доказано, что|отличный|а также|и способствуют|и способны|и очищают|и|а|поэтому|в том числе)\s*,?\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      res = res
          .replaceAll(
            RegExp(r'^(100%|натуральный природный|природный)\s+', caseSensitive: false),
            '',
          )
          .trim();
      res = res.replaceAll(RegExp(r'^(дает мощный)', caseSensitive: false), 'Обеспечивает');
      res = res.replaceAll(
        RegExp(
          r'^(является эффективным средством, как при|является эффективным средством при)',
          caseSensitive: false,
        ),
        'Эффективен при',
      );
      res = res
          .replaceAll(
            RegExp(
              r'^(компоненты фитосбора|природные компоненты, входящие в состав фитосбора,|компоненты, входящие в состав фитосбора,|природные компоненты|компоненты бальзама|компоненты)\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      res = res
          .replaceAll(
            RegExp(
              r'^(полезные свойства продукта:?|основные свойства:?|свойства продукта:?)\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      res = res.replaceAll(RegExp(r'^(не только\s+)', caseSensitive: false), '').trim();
      res = res.replaceAll(RegExp(r'^(но и\s+)', caseSensitive: false), '').trim();
      res = res.replaceAll(RegExp(r'[.;!]+$'), '').trim();
      if (res.isNotEmpty && res[0].toLowerCase() == res[0]) {
        res = res[0].toUpperCase() + res.substring(1);
      }
      return res;
    }

    final desc = product.description;
    final lines = desc
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    List<String> candidates = [];

    for (var l in lines) {
      final lower = l.toLowerCase();
      if (lower.startsWith('противопоказания') ||
          lower.startsWith('условия хранения') ||
          lower.startsWith('срок годности') ||
          lower.startsWith('форма выпуска') ||
          lower.startsWith('курс') ||
          lower.startsWith('масса') ||
          lower.startsWith('объем')) {
        continue;
      }

      final chunks = l.split(RegExp(r'(?<=[.;!])\s+|\s*;\s*'));
      for (var rawC in chunks) {
        var c = rawC.trim();
        if (c.contains('—')) {
          final parts = c.split('—');
          if (parts.length > 1) {
            var action = parts[1].trim();
            if (action.contains(':')) {
              action = action.split(':')[1].trim();
            }
            if (action.length >= 15 && hasBenefit(action)) {
              c = action;
            }
          }
        } else if (c.contains(' - ')) {
          final parts = c.split(' - ');
          if (parts.length > 1) {
            var action = parts[1].trim();
            if (action.contains(':')) {
              action = action.split(':')[1].trim();
            }
            if (action.length >= 15 && hasBenefit(action)) {
              c = action;
            }
          }
        } else if (c.contains(':') && !c.startsWith('http') && !c.toLowerCase().startsWith('состав')) {
          final parts = c.split(':');
          if (parts.length > 1) {
            var action = parts[1].trim();
            if (action.length >= 15 && hasBenefit(action)) {
              c = action;
            }
          }
        }

        List<String> subClauses = [c];
        if (c.contains(',') && c.length > 60) {
          final parts = c.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
          final benefitParts = parts.where((p) => hasBenefit(p)).toList();
          if (benefitParts.length >= 2) {
            subClauses = parts;
          } else if (parts.isNotEmpty &&
              parts[0].length >= 20 &&
              hasBenefit(parts[0]) &&
              !isGrammaticallyIncomplete(parts[0])) {
            subClauses = [parts[0]];
          }
        }

        for (var clause in subClauses) {
          final cleanC = cleanClause(clause);
          if (cleanC.length < 14 || cleanC.length > 78) continue;

          final cLower = cleanC.toLowerCase();
          if (nonBenefitWords.any((nb) => cLower.contains(nb))) continue;
          if (!hasBenefit(cleanC)) continue;
          if (isGrammaticallyIncomplete(cleanC)) continue;

          if (!candidates.contains(cleanC)) {
            candidates.add(cleanC);
          }
        }
      }
    }

    // Отбор 3 разнообразных тезисов
    List<String> finalBullets = [];
    for (var c in candidates) {
      final words = c.toLowerCase().split(RegExp(r'\s+')).take(2).toSet();
      final hasOverlap = finalBullets.any((b) {
        final bWords = b.toLowerCase().split(RegExp(r'\s+')).take(2).toSet();
        return words.intersection(bWords).length >= 2;
      });
      if (!hasOverlap) {
        finalBullets.add(c);
      }
      if (finalBullets.length >= 3) break;
    }

    if (finalBullets.length < 3) {
      for (var c in candidates) {
        if (!finalBullets.contains(c)) {
          finalBullets.add(c);
        }
        if (finalBullets.length >= 3) break;
      }
    }

    // Резервное наполнение при нехватке
    if (finalBullets.length < 3) {
      for (var l in lines) {
        final lower = l.toLowerCase();
        if (lower.startsWith('состав') ||
            lower.startsWith('способ') ||
            lower.startsWith('противопоказания') ||
            lower.startsWith('хранить') ||
            lower.startsWith('годен')) {
          continue;
        }
        final cl = cleanClause(l);
        if (cl.length >= 14 &&
            cl.length <= 75 &&
            !finalBullets.contains(cl) &&
            !isGrammaticallyIncomplete(cl)) {
          finalBullets.add(cl);
        }
        if (finalBullets.length >= 3) break;
      }
    }

    return finalBullets.take(3).toList();
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('🌊 Синий')),
                          selected: _promoTheme == 'blue',
                          selectedColor: const Color(0xFF1D4ED8),
                          labelStyle: TextStyle(
                            color: _promoTheme == 'blue' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoTheme = 'blue');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('❄️ Светло-голубой')),
                          selected: _promoTheme == 'sky',
                          selectedColor: const Color(0xFF0284C7),
                          labelStyle: TextStyle(
                            color: _promoTheme == 'sky' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoTheme = 'sky');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('🌹 Красный')),
                          selected: _promoTheme == 'red',
                          selectedColor: const Color(0xFFDC2626),
                          labelStyle: TextStyle(
                            color: _promoTheme == 'red' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoTheme = 'red');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('🌸 Светло-красный')),
                          selected: _promoTheme == 'light_red',
                          selectedColor: const Color(0xFFE11D48),
                          labelStyle: TextStyle(
                            color:
                                _promoTheme == 'light_red' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoTheme = 'light_red');
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

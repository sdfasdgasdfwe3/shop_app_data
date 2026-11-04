import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models.dart';
import '../../invoices_screen.dart';

class CartTab extends StatelessWidget {
  final AppData appData;
  final Map<String, int> cart;
  final Map<String, int> giftItems;
  final String repoUrl;
  final bool sendRetailPrice;
  final void Function(Map<String, int> newCart, Map<String, int> newGiftItems)
      onCartChanged;

  const CartTab({
    super.key,
    required this.appData,
    required this.cart,
    required this.giftItems,
    required this.repoUrl,
    required this.sendRetailPrice,
    required this.onCartChanged,
  });

  void _showQuantityDialog(
    BuildContext context,
    String key,
    bool isGift,
    int currentQty,
  ) {
    final controller = TextEditingController(text: currentQty.toString());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isGift ? 'Количество в подарок' : 'Оплачиваемое количество',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            labelText: 'Введите количество',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              final newCart = Map<String, int>.from(cart);
              final newGifts = Map<String, int>.from(giftItems);
              if (isGift) {
                if (val > 0) {
                  newGifts[key] = val;
                } else {
                  newGifts.remove(key);
                }
              } else {
                if (val > 0) {
                  newCart[key] = val;
                } else {
                  newCart.remove(key);
                }
              }
              onCartChanged(newCart, newGifts);
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showCreateInvoiceDialog(
    BuildContext context,
    int totalPrice,
    int totalPoints,
  ) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Оформление накладной',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'ID номер или ФИО (необязательно)',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Номер телефона (необязательно)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _createInvoice(
                context,
                totalPrice,
                totalPoints,
                nameController.text.trim(),
                phoneController.text.trim(),
              );
            },
            child: const Text('Сохранить накладную'),
          ),
        ],
      ),
    );
  }

  Future<void> _createInvoice(
    BuildContext context,
    int totalPrice,
    int totalPoints,
    String clientName,
    String clientPhone,
  ) async {
    if (cart.isEmpty && giftItems.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final invoicesStr = prefs.getString('saved_invoices') ?? '[]';
    List<dynamic> invoices = jsonDecode(invoicesStr);

    Map<String, int> invoiceItems = {};
    Set<String> allKeys = {...cart.keys, ...giftItems.keys};
    for (var k in allKeys) {
      invoiceItems[k] = (cart[k] ?? 0) + (giftItems[k] ?? 0);
    }

    final newInvoice = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'items': invoiceItems,
      'giftItems': Map<String, int>.from(giftItems),
      'totalPrice': totalPrice,
      'totalPoints': totalPoints,
      'clientName': clientName,
      'clientPhone': clientPhone,
    };

    invoices.insert(0, newInvoice);
    await prefs.setString('saved_invoices', jsonEncode(invoices));

    onCartChanged({}, {});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Накладная успешно сохранена!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    if (cart.isEmpty && giftItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 56,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ваша корзина пуста',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Добавьте товары из каталога',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: borderColor),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Посмотреть мои накладные'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InvoicesScreen(
                      appData: appData,
                      onEditInvoice: (items, invoiceGiftItems) {
                        final newGifts = Map<String, int>.from(
                          invoiceGiftItems.map(
                            (k, v) => MapEntry(k.toString(), v as int),
                          ),
                        );
                        final newCart = <String, int>{};
                        for (var entry in items.entries) {
                          int total = entry.value as int;
                          int gift = newGifts[entry.key] ?? 0;
                          int paid = total - gift;
                          if (paid > 0) {
                            newCart[entry.key] = paid;
                          }
                        }
                        onCartChanged(newCart, newGifts);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    int totalPrice = 0;
    int totalPoints = 0;
    List<Widget> cartWidgets = [];

    Set<String> allKeys = {...cart.keys, ...giftItems.keys};

    for (var key in allKeys) {
      final productId = int.tryParse(key) ?? -1;
      final paidQty = cart[key] ?? 0;
      final giftQty = giftItems[key] ?? 0;
      final product = appData.products.firstWhere(
        (p) => p.id == productId,
        orElse: () => Product(
          id: -1,
          name: '',
          description: '',
          image: '',
          price: 0,
          points: 0,
          category: '',
        ),
      );

      if (product.id != -1) {
        final int currentPrice = (sendRetailPrice && product.retailPrice > 0)
            ? product.retailPrice
            : product.price;
        totalPrice += currentPrice * paidQty;
        totalPoints += product.points * paidQty;

        cartWidgets.add(
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: borderColor, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: "$repoUrl/images/${product.image}",
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$currentPrice ₽ x $paidQty = ${currentPrice * paidQty} ₽',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Gift toggle
                        InkWell(
                          onTap: () {
                            final newGifts = Map<String, int>.from(giftItems);
                            if (giftQty > 0) {
                              newGifts.remove(key);
                            } else {
                              newGifts[key] = 1;
                            }
                            onCartChanged(cart, newGifts);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: giftQty > 0,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: null,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'В подарок',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (giftQty > 0) ...[
                          const SizedBox(height: 6),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: Color(0xFF059669),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () {
                                    final newGifts = Map<String, int>.from(giftItems);
                                    if (giftQty > 1) {
                                      newGifts[key] = giftQty - 1;
                                    } else {
                                      newGifts.remove(key);
                                    }
                                    onCartChanged(cart, newGifts);
                                  },
                                ),
                                Text(
                                  'Подарок: $giftQty',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    size: 16,
                                    color: Color(0xFF059669),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () {
                                    final newGifts = Map<String, int>.from(giftItems);
                                    newGifts[key] = giftQty + 1;
                                    onCartChanged(cart, newGifts);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Paid quantity stepper
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.remove,
                            size: 16,
                            color: paidQty > 0
                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: paidQty > 0
                              ? () {
                                  final newCart = Map<String, int>.from(cart);
                                  if (paidQty > 1) {
                                    newCart[key] = paidQty - 1;
                                  } else {
                                    newCart.remove(key);
                                  }
                                  onCartChanged(newCart, giftItems);
                                }
                              : null,
                        ),
                        GestureDetector(
                          onTap: () => _showQuantityDialog(
                            context,
                            key,
                            false,
                            paidQty,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$paidQty',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add,
                            size: 16,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () {
                            final newCart = Map<String, int>.from(cart);
                            newCart[key] = paidQty + 1;
                            onCartChanged(newCart, giftItems);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
              label: const Text(
                'Очистить корзину',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w500),
              ),
              onPressed: () {
                onCartChanged({}, {});
              },
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            children: cartWidgets,
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: borderColor, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Итого:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '$totalPrice ₽',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Всего баллов:',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalPoints баллов',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  onPressed: () =>
                      _showCreateInvoiceDialog(context, totalPrice, totalPoints),
                  label: const Text(
                    'Сформировать накладную',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

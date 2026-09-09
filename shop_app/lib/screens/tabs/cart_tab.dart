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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isGift ? 'Количество в подарок' : 'Оплачиваемое количество',
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
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
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Оформление накладной'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'ID номер (необязательно)',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
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
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
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
            child: const Text('Сохранить'),
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
        const SnackBar(content: Text('Накладная успешно сформирована!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty && giftItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Корзина пуста',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.receipt_long),
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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: "$repoUrl/images/${product.image}",
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$currentPrice ₽ x $paidQty = ${currentPrice * paidQty} ₽',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                final newGifts =
                                    Map<String, int>.from(giftItems);
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
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: giftQty > 0,
                                      onChanged: null,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'В подарок',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (giftQty > 0) ...[
                              const SizedBox(height: 6),
                              Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove,
                                        size: 18,
                                        color: Colors.green,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: () {
                                        final newGifts =
                                            Map<String, int>.from(giftItems);
                                        if (giftQty > 1) {
                                          newGifts[key] = giftQty - 1;
                                        } else {
                                          newGifts.remove(key);
                                        }
                                        onCartChanged(cart, newGifts);
                                      },
                                    ),
                                    GestureDetector(
                                      onTap: () => _showQuantityDialog(
                                        context,
                                        key,
                                        true,
                                        giftQty,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$giftQty',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add,
                                        size: 18,
                                        color: Colors.green,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: () {
                                        final newGifts =
                                            Map<String, int>.from(giftItems);
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
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: paidQty > 0 ? Colors.red : Colors.grey,
                        ),
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$paidQty',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.green,
                        ),
                        onPressed: () {
                          final newCart = Map<String, int>.from(cart);
                          newCart[key] = paidQty + 1;
                          onCartChanged(newCart, giftItems);
                        },
                      ),
                    ],
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
          padding: const EdgeInsets.only(right: 16.0, top: 8.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              label: const Text(
                'Очистить корзину',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                onCartChanged({}, {});
              },
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            children: cartWidgets,
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
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
                  const Text(
                    'Итого:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$totalPrice ₽',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Всего баллов:',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  Text(
                    '$totalPoints',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.receipt_long),
                onPressed: () =>
                    _showCreateInvoiceDialog(context, totalPrice, totalPoints),
                label: const Text(
                  'Сформировать накладную',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

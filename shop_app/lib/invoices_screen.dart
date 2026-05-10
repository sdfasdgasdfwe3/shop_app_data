import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../models.dart';

// --- Экран списка накладных ---
class InvoicesScreen extends StatefulWidget {
  final AppData appData;
  final Function(Map<String, dynamic>) onEditInvoice;

  const InvoicesScreen({
    super.key,
    required this.appData,
    required this.onEditInvoice,
  });

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<dynamic> _invoices = [];
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('saved_invoices') ?? '[]';
    setState(() {
      _invoices = jsonDecode(str);
    });
  }

  Future<void> _saveInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_invoices', jsonEncode(_invoices));
  }

  void _deleteInvoice(int index) {
    setState(() {
      _invoices.removeAt(index);
    });
    _saveInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = _invoices.where((invoice) {
      final clientName = (invoice['clientName'] as String? ?? '').toLowerCase();
      final clientPhone = (invoice['clientPhone'] as String? ?? '')
          .toLowerCase();
      final query = _searchQuery.toLowerCase();
      return clientName.contains(query) || clientPhone.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Мои накладные')),
      body: Column(
        children: [
          if (_invoices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Поиск по имени или телефону...',
                  prefixIcon: const Icon(Icons.search, color: Colors.blue),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          Expanded(
            child: filteredInvoices.isEmpty
                ? const Center(
                    child: Text(
                      'Накладные не найдены',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 8,
                      bottom: 16,
                    ),
                    itemCount: filteredInvoices.length,
                    itemBuilder: (context, index) {
                      final invoice = filteredInvoices[index];
                      final originalIndex = _invoices.indexOf(
                        invoice,
                      ); // Ищем реальный индекс для удаления/редактирования
                      final items = invoice['items'] as Map<String, dynamic>;
                      final dateStr = invoice['date'] as String;
                      final date = DateTime.tryParse(dateStr) ?? DateTime.now();
                      final formattedDate =
                          "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                      final clientName = invoice['clientName'] as String? ?? '';
                      final clientPhone =
                          invoice['clientPhone'] as String? ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Накладная от $formattedDate',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Сумма: ${invoice['totalPrice']} ₽ | Баллы: ${invoice['totalPoints']}',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (clientName.isNotEmpty ||
                                  clientPhone.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Клиент: $clientName ${clientPhone.isNotEmpty ? '($clientPhone)' : ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Text(
                                'Товары:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              ...items.entries.map((e) {
                                final pId = int.parse(e.key);
                                final q = e.value;
                                final p = widget.appData.products.firstWhere(
                                  (p) => p.id == pId,
                                  orElse: () => Product(
                                    id: -1,
                                    name: 'Неизвестно',
                                    description: '',
                                    image: '',
                                    price: 0,
                                    points: 0,
                                    category: '',
                                  ),
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text('- ${p.name} (x$q)'),
                                );
                              }),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.share,
                                      color: Colors.green,
                                    ),
                                    label: const Text(
                                      'Поделиться',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                    onPressed: () {
                                      String shareText =
                                          '📦 Ваш заказ успешно оформлен!\n📄 Накладная от $formattedDate\n\n';
                                      if (clientName.isNotEmpty) {
                                        shareText += '👤 Клиент: $clientName\n';
                                      }
                                      if (clientPhone.isNotEmpty) {
                                        shareText +=
                                            '📞 Телефон: $clientPhone\n';
                                      }
                                      shareText += '\n🛒 Список товаров:\n';
                                      for (var e in items.entries) {
                                        final pId = int.parse(e.key);
                                        final q = e.value;
                                        final p = widget.appData.products
                                            .firstWhere(
                                              (p) => p.id == pId,
                                              orElse: () => Product(
                                                id: -1,
                                                name: 'Неизвестно',
                                                description: '',
                                                image: '',
                                                price: 0,
                                                points: 0,
                                                category: '',
                                              ),
                                            );
                                        if (p.id != -1) {
                                          shareText +=
                                              '▫️ ${p.name} — $q шт. x ${p.price} ₽ = ${p.price * q} ₽\n';
                                        }
                                      }
                                      shareText +=
                                          '\n💰 Итого к оплате: ${invoice['totalPrice']} ₽\n';
                                      shareText +=
                                          '⭐️ Начислено баллов: ${invoice['totalPoints']}\n\n';
                                      shareText += 'Благодарим за покупку! 💙';
                                      Share.share(shareText);
                                    },
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        tooltip: 'Изменить',
                                        onPressed: () {
                                          final itemsToEdit = items;
                                          _deleteInvoice(originalIndex);
                                          Navigator.pop(context);
                                          widget.onEditInvoice(itemsToEdit);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Удалить',
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Удаление'),
                                              content: const Text(
                                                'Удалить эту накладную?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
                                                  child: const Text('Отмена'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(ctx);
                                                    _deleteInvoice(
                                                      originalIndex,
                                                    );
                                                  },
                                                  child: const Text(
                                                    'Удалить',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

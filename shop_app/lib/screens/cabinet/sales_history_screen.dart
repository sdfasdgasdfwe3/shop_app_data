import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SalesHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String apiBaseUrl;

  const SalesHistoryScreen({
    super.key,
    required this.user,
    this.apiBaseUrl = 'https://znam.space',
  });

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _orders = [];
  String? _emptyMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ticket = widget.user['ticket'] ?? widget.user['partnersTicket'] ?? '';
      final guid = widget.user['partnersGuid'] ?? '';
      final utckt = widget.user['usersTicket'] ?? widget.user['utckt'] ?? '';
      final login = widget.user['login'] ?? widget.user['email'] ?? widget.user['partnerId'] ?? '';
      final password = widget.user['password'] ?? '';

      final url = Uri.parse(
        '${widget.apiBaseUrl}/api/cabinet/orders?ticket=$ticket&guid=$guid&utckt=$utckt&login=${Uri.encodeComponent(login)}&password=${Uri.encodeComponent(password)}',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 25));
      final data = jsonDecode(utf8.decode(res.bodyBytes));

      if (data['success'] == true) {
        setState(() {
          _orders = data['orders'] ?? [];
          _emptyMessage = data['message'];
          _isLoading = false;
        });
      } else {
        throw Exception(data['error'] ?? 'Не удалось загрузить историю заказов');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История заказов', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOrders,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _fetchOrders,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.blue),
              ),
              const SizedBox(height: 16),
              Text(
                _emptyMessage ?? 'У вас пока нет оформленных заказов',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Здесь будут отображаться ваши накладные, баллы личного объема (ЛО) и статус доставки.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final number = (order['number'] ?? order['invoiceNumber'] ?? order['orderNumber'] ?? order['id'] ?? 'Заказ').toString();
        final date = (order['date'] ?? order['orderDate'] ?? order['saleDate'] ?? '').toString();
        final warehouse = (order['warehouse'] ?? order['warehouseName'] ?? '').toString();
        final sum = (order['sum'] ?? order['total'] ?? order['totalSum'] ?? '0 ₽').toString();
        final points = (order['points'] ?? order['lop'] ?? '0 ЛО').toString();
        final status = (order['status'] ?? order['state'] ?? 'Выполнен').toString();
        final items = (order['items'] ?? order['products'] ?? '').toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(date, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    if (warehouse.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.warehouse_outlined, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(warehouse, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ],
                ),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Сумма: $sum',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        points,
                        style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      items,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AccountsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String apiBaseUrl;

  const AccountsScreen({
    super.key,
    required this.user,
    this.apiBaseUrl = 'https://znam.space',
  });

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _accounts = [];
  List<dynamic> _operations = [];
  String? _emptyMessage;
  String? _stock;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ticket = widget.user['ticket'] ?? widget.user['partnersTicket'] ?? '';
      final guid = widget.user['partnersGuid'] ?? '';
      final utckt = widget.user['usersTicket'] ?? '';

      final url = Uri.parse(
        '${widget.apiBaseUrl}/api/cabinet/accounts?ticket=$ticket&guid=$guid&utckt=$utckt',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 20));
      final data = jsonDecode(utf8.decode(res.bodyBytes));

      if (data['success'] == true) {
        setState(() {
          _accounts = data['accounts'] ?? [];
          _operations = data['operations'] ?? [];
          _emptyMessage = data['message'];
          if (data['stock'] != null && data['stock'].toString().isNotEmpty) {
            _stock = data['stock'].toString();
          }
          _isLoading = false;
        });
      } else {
        throw Exception(data['error'] ?? 'Не удалось загрузить данные счетов');
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
        title: const Text('Мои счета', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAccounts,
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
                onPressed: _fetchAccounts,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Общий баланс из статистики кабинета
        Builder(
          builder: (context) {
            final currentStock = _stock ?? widget.user['stats']?['stock'] ?? '0 Бонус';
            final bonus = widget.user['stats']?['bonus'] ?? '0 ₽';
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade800, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade900.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Текущий остаток',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Icon(Icons.account_balance_wallet, color: Colors.white70, size: 22),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      currentStock,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Начисленный бонус: $bonus',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // Счета
        if (_accounts.isNotEmpty) ...[
          const Text(
            'Доступные счета',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ..._accounts.map((acc) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.credit_card, color: Colors.blue),
                ),
                title: Text(
                  acc['title'] ?? 'Счет',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ] else if (_emptyMessage != null && _emptyMessage!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _emptyMessage!,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // История операций
        const Text(
          'История операций',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (_operations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Операций по счетам пока не зафиксировано',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ),
          )
        else
          ..._operations.map((op) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
              ),
              child: ListTile(
                title: Text(op['type'] ?? 'Операция', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (op['description'] != null && op['description'].isNotEmpty)
                      Text(op['description'], style: const TextStyle(fontSize: 12)),
                    Text(op['date'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
                trailing: Text(
                  op['sum'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: (op['sum']?.toString().contains('-') ?? false) ? Colors.red : Colors.green,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

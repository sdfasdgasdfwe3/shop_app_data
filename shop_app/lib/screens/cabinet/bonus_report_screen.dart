import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BonusReportScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String apiBaseUrl;

  const BonusReportScreen({
    super.key,
    required this.user,
    this.apiBaseUrl = 'https://znam.space',
  });

  @override
  State<BonusReportScreen> createState() => _BonusReportScreenState();
}

class _BonusReportScreenState extends State<BonusReportScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _bonuses = [];
  String? _emptyMessage;

  @override
  void initState() {
    super.initState();
    _fetchBonuses();
  }

  Future<void> _fetchBonuses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ticket = widget.user['ticket'] ?? widget.user['partnersTicket'] ?? '';
      final guid = widget.user['partnersGuid'] ?? '';
      final utckt = widget.user['usersTicket'] ?? '';

      final url = Uri.parse(
        '${widget.apiBaseUrl}/api/cabinet/bonuses?ticket=$ticket&guid=$guid&utckt=$utckt',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 20));
      final data = jsonDecode(utf8.decode(res.bodyBytes));

      if (data['success'] == true) {
        setState(() {
          _bonuses = data['bonuses'] ?? [];
          _emptyMessage = data['message'];
          _isLoading = false;
        });
      } else {
        throw Exception(data['error'] ?? 'Не удалось загрузить отчет по вознаграждениям');
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
    final bonusCurrent = widget.user['stats']?['bonus'] ?? '0 ₽';
    final bonusInc = widget.user['stats']?['bonusIncrease'] ?? '0%';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои вознаграждения', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchBonuses,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Карточка текущего бонуса
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade700, Colors.orange.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.shade900.withValues(alpha: 0.25),
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
                      Text('Текущий начисленный бонус', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bonusCurrent,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Динамика за период: $bonusInc',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'История начислений по периодам',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              )
            else if (_bonuses.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      _emptyMessage ?? 'Данные по вознаграждениям пока не сформированы.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._bonuses.map((b) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
                  ),
                  child: ListTile(
                    title: Text(b['bonusType'] ?? 'Бонус', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(b['period'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    trailing: Text(
                      b['sum'] ?? '0 ₽',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

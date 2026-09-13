import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class DownlineScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String apiBaseUrl;

  const DownlineScreen({
    super.key,
    required this.user,
    this.apiBaseUrl = 'https://znam.space',
  });

  @override
  State<DownlineScreen> createState() => _DownlineScreenState();
}

class _DownlineScreenState extends State<DownlineScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _allPartners = [];
  List<dynamic> _filteredPartners = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDownline();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredPartners = _allPartners;
      } else {
        _filteredPartners = _allPartners.where((p) {
          final fio = (p['Fio'] ?? '').toString().toLowerCase();
          final id = (p['Id'] ?? '').toString().toLowerCase();
          final city = (p['City'] ?? '').toString().toLowerCase();
          return fio.contains(q) || id.contains(q) || city.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _fetchDownline() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ticket = widget.user['ticket'] ?? widget.user['partnersTicket'] ?? '';
      final guid = widget.user['partnersGuid'] ?? '';
      final utckt = widget.user['usersTicket'] ?? '';

      final url = Uri.parse(
        '${widget.apiBaseUrl}/api/cabinet/downline?ticket=$ticket&guid=$guid&utckt=$utckt',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 25));
      final data = jsonDecode(utf8.decode(res.bodyBytes));

      if (data['success'] == true) {
        setState(() {
          _allPartners = data['partners'] ?? [];
          _filteredPartners = _allPartners;
          _isLoading = false;
        });
      } else {
        throw Exception(data['error'] ?? 'Не удалось загрузить структуру');
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
        title: Text('Структура (${_allPartners.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDownline,
        child: Column(
          children: [
            // Поиск по структуре
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Поиск по ФИО, ID или городу...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
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
                onPressed: _fetchDownline,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredPartners.isEmpty) {
      return Center(
        child: Text(
          _allPartners.isEmpty
              ? 'У вас пока нет зарегистрированных участников в структуре'
              : 'Участники по запросу не найдены',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: _filteredPartners.length,
      itemBuilder: (context, index) {
        final p = _filteredPartners[index];
        final level = p['Level'] ?? 0;
        final fio = (p['Fio'] ?? 'Партнер').toString();
        final id = (p['Id'] ?? '').toString();
        final city = (p['City'] ?? '').toString();
        final sponsor = (p['SponsorFio'] ?? '').toString();
        final lop = p['TotalSum_4'] != null ? '${p['TotalSum_4']} ЛО' : '0 ЛО';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: level == 0
                  ? Colors.blue.withValues(alpha: 0.5)
                  : Theme.of(context).dividerColor.withValues(alpha: 0.15),
              width: level == 0 ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Уровень / Аватар
                CircleAvatar(
                  radius: 20,
                  backgroundColor: level == 0
                      ? Colors.blue.shade700
                      : Colors.blue.withValues(alpha: 0.1),
                  child: Text(
                    'Ур.$level',
                    style: TextStyle(
                      color: level == 0 ? Colors.white : Colors.blue.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              fio,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lop,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('ID: $id', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('ID скопирован'), duration: Duration(seconds: 1)),
                              );
                            },
                            child: Icon(Icons.copy, size: 13, color: Colors.blue.shade700),
                          ),
                          if (city.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 2),
                            Text(city, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ],
                      ),
                      if (sponsor.isNotEmpty && level > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Спонсор: $sponsor',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

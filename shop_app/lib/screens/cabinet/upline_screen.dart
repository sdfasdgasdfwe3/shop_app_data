import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UplineScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String apiBaseUrl;

  const UplineScreen({
    super.key,
    required this.user,
    this.apiBaseUrl = 'https://znam.space',
  });

  @override
  State<UplineScreen> createState() => _UplineScreenState();
}

class _UplineScreenState extends State<UplineScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _uplineList = [];

  @override
  void initState() {
    super.initState();
    _fetchUpline();
  }

  Future<void> _fetchUpline() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ticket = widget.user['ticket'] ?? widget.user['partnersTicket'] ?? '';
      final guid = widget.user['partnersGuid'] ?? '';
      final utckt = widget.user['usersTicket'] ?? '';

      final url = Uri.parse(
        '${widget.apiBaseUrl}/api/cabinet/upline?ticket=$ticket&guid=$guid&utckt=$utckt',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 20));
      final data = jsonDecode(utf8.decode(res.bodyBytes));

      if (data['success'] == true) {
        setState(() {
          _uplineList = data['upline'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception(data['error'] ?? 'Не удалось загрузить спонсоров');
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
        title: const Text('Вышестоящие спонсоры', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUpline,
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
                onPressed: _fetchUpline,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_uplineList.isEmpty) {
      return const Center(
        child: Text('Вышестоящие спонсоры не найдены', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _uplineList.length,
      itemBuilder: (context, index) {
        final item = _uplineList[index];
        final rowNum = item['rowNum'] ?? (index + 1);
        final fio = (item['fio'] ?? 'Спонсор').toString();
        final id = (item['id'] ?? '').toString();
        final email = (item['email'] ?? '').toString();
        final phone = (item['phone'] ?? '').toString();
        final isDirect = index == 0;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDirect ? Colors.blue.shade300 : Theme.of(context).dividerColor.withValues(alpha: 0.15),
              width: isDirect ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isDirect ? Colors.blue.shade700 : Colors.blue.withValues(alpha: 0.1),
                      child: Text(
                        '$rowNum',
                        style: TextStyle(
                          color: isDirect ? Colors.white : Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isDirect)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Прямой спонсор',
                                style: TextStyle(color: Colors.blue.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          Text(
                            fio,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
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
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty || phone.isNotEmpty) ...[
                  const Divider(height: 20),
                  if (email.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.email, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(email, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                      ],
                    ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(phone, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.call, size: 18, color: Colors.green),
                          onPressed: () async {
                            final uri = Uri.parse('tel:$phone');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class InvitedScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String apiBaseUrl;

  const InvitedScreen({
    super.key,
    required this.user,
    this.apiBaseUrl = 'https://znam.space',
  });

  @override
  State<InvitedScreen> createState() => _InvitedScreenState();
}

class _InvitedScreenState extends State<InvitedScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _invitedList = [];

  @override
  void initState() {
    super.initState();
    _fetchInvited();
  }

  Future<void> _fetchInvited() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ticket = widget.user['ticket'] ?? widget.user['partnersTicket'] ?? '';
      final guid = widget.user['partnersGuid'] ?? '';
      final utckt = widget.user['usersTicket'] ?? '';

      final url = Uri.parse(
        '${widget.apiBaseUrl}/api/cabinet/invited?ticket=$ticket&guid=$guid&utckt=$utckt',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 20));
      final data = jsonDecode(utf8.decode(res.bodyBytes));

      if (data['success'] == true) {
        setState(() {
          _invitedList = data['invited'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception(data['error'] ?? 'Не удалось загрузить список приглашенных');
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

  void _shareReferralLink() {
    final refLink = widget.user['referralLink'] ??
        (widget.user['partnersGuid'] != null
            ? 'https://infinity-mlm.com/user/registration?ref=${widget.user['partnersGuid']}&warehouse=1'
            : '');
    if (refLink.isNotEmpty) {
      Share.share('Присоединяйтесь к моей команде в НПК ИНФИНИТИ: $refLink');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Лично приглашенные (${_invitedList.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Поделиться реферальной ссылкой',
            onPressed: _shareReferralLink,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchInvited,
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
                onPressed: _fetchInvited,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_invitedList.isEmpty) {
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
                child: const Icon(Icons.group_add_rounded, size: 48, color: Colors.blue),
              ),
              const SizedBox(height: 16),
              const Text(
                'Пока нет лично приглашенных',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Поделитесь вашей персональной реферальной ссылкой, чтобы пригласить новых участников в вашу первую линию.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _shareReferralLink,
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Пригласить партнера'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _invitedList.length,
      itemBuilder: (context, index) {
        final item = _invitedList[index];
        final fio = (item['fio'] ?? item['Fio'] ?? 'Партнер').toString();
        final id = (item['id'] ?? item['Id'] ?? '').toString();
        final phone = (item['phone'] ?? item['Phone'] ?? '').toString();
        final email = (item['email'] ?? item['Email'] ?? '').toString();
        final city = (item['city'] ?? item['City'] ?? '').toString();
        final regDate = (item['registrationDate'] ?? item['RegistrationDate'] ?? '').toString();

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
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
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue.shade700,
                      child: Text(
                        fio.isNotEmpty ? fio[0].toUpperCase() : 'П',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fio, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                const Divider(height: 20),
                if (city.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 15, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(city, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (email.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.email, size: 15, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(email, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (phone.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.phone, size: 15, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(phone, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.call, size: 18, color: Colors.green),
                        onPressed: () async {
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat, size: 18, color: Colors.teal),
                        onPressed: () async {
                          final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
                          final uri = Uri.parse('https://wa.me/$cleanPhone');
                          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                      ),
                    ],
                  ),
                ],
                if (regDate.isNotEmpty)
                  Text(
                    'Зарегистрирован: ${regDate.split('T').first}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

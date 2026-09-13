import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String apiBaseUrl;
  final VoidCallback? onProfileUpdated;

  const EditProfileScreen({
    super.key,
    required this.user,
    this.apiBaseUrl = 'https://znam.space',
    this.onProfileUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ticket = widget.user['ticket'] ?? widget.user['partnersTicket'] ?? '';
      final guid = widget.user['partnersGuid'] ?? '';
      final utckt = widget.user['usersTicket'] ?? '';

      final url = Uri.parse(
        '${widget.apiBaseUrl}/api/cabinet/profile?ticket=$ticket&guid=$guid&utckt=$utckt',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 20));
      final data = jsonDecode(utf8.decode(res.bodyBytes));

      if (data['success'] == true && data['profile'] != null) {
        setState(() {
          _profileData = Map<String, dynamic>.from(data['profile']);
          _isLoading = false;
        });
      } else {
        throw Exception(data['error'] ?? 'Не удалось загрузить данные профиля');
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

  Future<void> _updateField(String action, Map<String, dynamic> bodyFields) async {
    final ticket = widget.user['ticket'] ?? widget.user['partnersTicket'] ?? '';
    final guid = widget.user['partnersGuid'] ?? '';
    final utckt = widget.user['usersTicket'] ?? '';

    final payload = {
      'ticket': ticket,
      'guid': guid,
      'utckt': utckt,
      'action': action,
      ...bodyFields,
    };

    try {
      final res = await http
          .post(
            Uri.parse('${widget.apiBaseUrl}/api/cabinet/update-profile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (!mounted) return;

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Данные успешно обновлены'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        _fetchProfile();
        widget.onProfileUpdated?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? data['error'] ?? 'Ошибка сохранения данных'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка сети: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showEditCityDialog() {
    final currentCity = _profileData?['city'] ?? widget.user['city'] ?? '';
    final controller = TextEditingController(text: currentCity);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить город'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Город проживания',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final newCity = controller.text.trim();
              if (newCity.isNotEmpty) {
                Navigator.pop(ctx);
                _updateField('city', {'city': newCity});
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showEditFioDialog() {
    final parts = (_profileData?['fio'] ?? widget.user['partnerName'] ?? '').split(' ');
    final last = parts.isNotEmpty ? parts[0] : (widget.user['lastName'] ?? '');
    final first = parts.length > 1 ? parts[1] : (widget.user['firstName'] ?? '');
    final patr = parts.length > 2 ? parts[2] : (widget.user['patronymic'] ?? '');

    final lastController = TextEditingController(text: last);
    final firstController = TextEditingController(text: first);
    final patrController = TextEditingController(text: patr);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить ФИО'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: lastController,
                decoration: const InputDecoration(
                  labelText: 'Фамилия *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: firstController,
                decoration: const InputDecoration(
                  labelText: 'Имя *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: patrController,
                decoration: const InputDecoration(
                  labelText: 'Отчество',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final l = lastController.text.trim();
              final f = firstController.text.trim();
              final p = patrController.text.trim();
              if (l.isNotEmpty && f.isNotEmpty) {
                Navigator.pop(ctx);
                _updateField('fio', {
                  'lastName': l,
                  'firstName': f,
                  'patronymic': p,
                });
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Изменить пароль'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldController,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'Старый пароль',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newController,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'Новый пароль',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'Повторите новый пароль',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: !obscure,
                      onChanged: (v) => setDlgState(() => obscure = !v!),
                    ),
                    const Text('Показать пароль', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final oldP = oldController.text.trim();
                final newP = newController.text.trim();
                final confP = confirmController.text.trim();

                if (oldP.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Введите текущий пароль')),
                  );
                  return;
                }
                if (newP.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Новый пароль должен быть не менее 6 символов')),
                  );
                  return;
                }
                if (newP != confP) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Пароли не совпадают')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                _updateField('password', {
                  'oldPassword': oldP,
                  'newPassword': newP,
                });
              },
              child: const Text('Сменить пароль'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Личные данные', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfile,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _profileData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить попытку'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _profileData ?? {};
    final partnerId = data['partnerId'] ?? widget.user['partnerId'] ?? '';
    final fio = data['fio'] ?? widget.user['partnerName'] ?? '—';
    final phone = data['phone'] ?? widget.user['phone'] ?? '—';
    final email = data['email'] ?? widget.user['email'] ?? '—';
    final city = data['city'] ?? widget.user['city'] ?? '—';
    final country = data['country'] ?? 'Россия';
    final birthday = data['birthday'] ?? 'Не указано';
    final gender = data['gender'] ?? 'Не указан';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, size: 36, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fio,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (partnerId.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ID: $partnerId',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Personal Information block
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Анкетные данные',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 20),

                // ФИО
                _buildActionRow(
                  icon: Icons.badge_outlined,
                  label: 'ФИО',
                  value: fio,
                  actionText: 'Изменить',
                  onAction: _showEditFioDialog,
                ),
                const Divider(height: 20),

                // Телефон
                _buildSimpleRow(
                  icon: Icons.phone_outlined,
                  label: 'Телефон',
                  value: phone,
                ),
                const Divider(height: 20),

                // Email
                _buildSimpleRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: email,
                  isCopyable: true,
                ),
                const Divider(height: 20),

                // Город
                _buildActionRow(
                  icon: Icons.location_city_outlined,
                  label: 'Город',
                  value: city,
                  actionText: 'Изменить',
                  onAction: _showEditCityDialog,
                ),
                const Divider(height: 20),

                // Страна
                _buildSimpleRow(
                  icon: Icons.flag_outlined,
                  label: 'Страна',
                  value: country,
                ),
                const Divider(height: 20),

                // Дата рождения
                _buildSimpleRow(
                  icon: Icons.cake_outlined,
                  label: 'Дата рождения',
                  value: birthday,
                ),
                const Divider(height: 20),

                // Пол
                _buildSimpleRow(
                  icon: Icons.wc_outlined,
                  label: 'Пол',
                  value: gender,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Security card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Безопасность',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock_reset, color: Colors.orange),
                  ),
                  title: const Text('Сменить пароль', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Обновите пароль для входа в кабинет', style: TextStyle(fontSize: 12)),
                  trailing: OutlinedButton(
                    onPressed: _showChangePasswordDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(color: Colors.orange.shade800),
                    ),
                    child: const Text('Изменить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleRow({
    required IconData icon,
    required String label,
    required String value,
    bool isCopyable = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (isCopyable)
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: Colors.blue),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label скопирован'), duration: const Duration(seconds: 1)),
              );
            },
          ),
      ],
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required String value,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(actionText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

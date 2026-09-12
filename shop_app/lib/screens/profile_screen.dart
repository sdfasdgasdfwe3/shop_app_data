import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String apiBaseUrl = 'https://91-108-239-242.sslip.io';

  Map<String, dynamic>? _savedUser;
  bool _isLoadingUser = true;

  // Регистрационная сессия
  bool _isInitializing = false;
  bool _isSubmitting = false;
  String? _sessionId;
  String? _generatedEmail;
  String? _captchaBase64;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _patronymicController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _sponsorController = TextEditingController();
  final _captchaController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedUser();
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _patronymicController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _sponsorController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('saved_auth_user');
      if (userStr != null && userStr.isNotEmpty) {
        setState(() {
          _savedUser = jsonDecode(userStr);
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки профиля: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
      }
    }
  }

  Future<void> _startRegistration() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/api/session'))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _sessionId = data['sessionId'];
            _generatedEmail = data['email'];
            _captchaBase64 = data['captcha'];
            _isInitializing = false;
          });
          return;
        } else {
          throw Exception(data['error'] ?? 'Ошибка инициализации сессии');
        }
      } else {
        throw Exception('Сервер вернул код ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  Future<void> _reloadCaptcha() async {
    if (_sessionId == null) return;
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/api/captcha?sessionId=$_sessionId'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['captcha'] != null) {
          setState(() {
            _captchaBase64 = data['captcha'];
            _captchaController.clear();
          });
        }
      }
    } catch (e) {
      debugPrint('Ошибка обновления капчи: $e');
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sessionId == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final payload = {
        'sessionId': _sessionId,
        'lastName': _lastNameController.text.trim(),
        'firstName': _firstNameController.text.trim(),
        'patronymic': _patronymicController.text.trim(),
        'city': _cityController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text.trim(),
        'sponsor': _sponsorController.text.trim(),
        'captcha': _captchaController.text.trim(),
      };

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final userData = {
          'email': data['email'] ?? _generatedEmail,
          'password': _passwordController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'firstName': _firstNameController.text.trim(),
          'city': _cityController.text.trim(),
          'phone': _phoneController.text.trim(),
          'ticket': data['ticket'] ?? '',
          'registeredAt': DateTime.now().toIso8601String(),
        };

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_auth_user', jsonEncode(userData));

        if (mounted) {
          setState(() {
            _savedUser = userData;
            _sessionId = null;
            _isSubmitting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Регистрация успешно завершена!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (data['newCaptcha'] != null) {
          setState(() {
            _captchaBase64 = data['newCaptcha'];
            _captchaController.clear();
          });
        }
        throw Exception(data['error'] ?? 'Ошибка при регистрации');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выход из профиля'),
        content: const Text('Вы уверены, что хотите сбросить сохраненный профиль?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_auth_user');
      setState(() {
        _savedUser = null;
        _sessionId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        centerTitle: true,
      ),
      body: _isLoadingUser
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: _savedUser != null
                      ? _buildProfileCard()
                      : _sessionId != null
                          ? _buildRegistrationForm()
                          : _buildInitialCard(),
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    final email = _savedUser!['email'] ?? '';
    final name = '${_savedUser!['lastName'] ?? ''} ${_savedUser!['firstName'] ?? ''}'.trim();
    final phone = _savedUser!['phone'] ?? '';
    final city = _savedUser!['city'] ?? '';
    final password = _savedUser!['password'] ?? '';
    final ticket = _savedUser!['ticket'] ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, color: Colors.blue, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Партнер НПК ИНФИНИТИ',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            if (ticket.isNotEmpty) ...[
              _buildInfoRow('Номер билета/ID', ticket, isCopyable: true),
              const SizedBox(height: 12),
            ],
            if (phone.isNotEmpty) ...[
              _buildInfoRow('Телефон', phone),
              const SizedBox(height: 12),
            ],
            if (city.isNotEmpty) ...[
              _buildInfoRow('Город', city),
              const SizedBox(height: 12),
            ],
            if (password.isNotEmpty) ...[
              _buildInfoRow('Пароль', password, isCopyable: true),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final url = Uri.parse('https://infinity-mlm.com/user/myaccount');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Перейти на infinity-mlm.com'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 18, color: Colors.red),
                label: const Text('Выйти / Сменить аккаунт', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isCopyable = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (isCopyable) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label скопирован'), duration: const Duration(seconds: 1)),
                  );
                },
                child: Icon(Icons.copy, size: 16, color: Colors.blue.shade700),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildInitialCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_circle, size: 48, color: Colors.blue),
            ),
            const SizedBox(height: 16),
            const Text(
              'Регистрация в НПК ИНФИНИТИ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Создайте аккаунт партнера прямо из приложения. Подтверждение почты произойдет автоматически через наш сервер.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isInitializing ? null : _startRegistration,
                child: _isInitializing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Подтверждение почты (~20 сек)...'),
                        ],
                      )
                    : const Text('Начать регистрацию', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    Uint8List? captchaBytes;
    if (_captchaBase64 != null) {
      try {
        final cleanBase64 = _captchaBase64!.split(',').last;
        captchaBytes = base64Decode(cleanBase64);
      } catch (e) {
        debugPrint('Ошибка декодирования капчи: $e');
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Анкета партнера',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _sessionId = null;
                      });
                    },
                    tooltip: 'Отмена',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Email подтвержден: $_generatedEmail',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.green),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Фамилия *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Укажите фамилию' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Имя *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Укажите имя' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _patronymicController,
                decoration: const InputDecoration(
                  labelText: 'Отчество (опционально)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Город *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Укажите город' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Телефон *',
                  hintText: 'Например: 9991234567',
                  prefixText: '+7 ',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Укажите телефон';
                  final digits = v.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10) return 'Минимум 10 цифр';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Пароль *',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (v) => v == null || v.length < 6 ? 'Минимум 6 символов' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sponsorController,
                decoration: const InputDecoration(
                  labelText: 'ID Спонсора (если есть)',
                  hintText: 'Оставьте пустым, если нет',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _captchaController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: 'Код с картинки *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Введите код' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (captchaBytes != null)
                    Container(
                      height: 48,
                      width: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.memory(captchaBytes, fit: BoxFit.fill),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _reloadCaptcha,
                    tooltip: 'Обновить картинку',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitRegistration,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Зарегистрироваться', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

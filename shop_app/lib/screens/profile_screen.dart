import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  final bool showAppBar;
  final VoidCallback? onLoginStateChanged;

  const ProfileScreen({
    super.key,
    this.showAppBar = true,
    this.onLoginStateChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String apiBaseUrl = 'https://znam.space';

  Map<String, dynamic>? _savedUser;
  bool _isLoadingUser = true;

  // Регистрационная сессия
  bool _isInitializingAuto = false;
  int _autoSecondsElapsed = 0;
  Timer? _autoTimer;
  bool _isSendingPin = false;
  bool _isVerifyingPin = false;
  bool _isSubmitting = false;

  bool _pinSent = false;
  String? _customEmailSentTo;

  String? _sessionId;
  String? _activeEmail;
  String? _captchaBase64;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final _customEmailController = TextEditingController();
  final _pinController = TextEditingController();

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
    _customEmailController.dispose();
    _pinController.dispose();
    _lastNameController.dispose();
    _firstNameController.dispose();
    _patronymicController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _sponsorController.dispose();
    _captchaController.dispose();
    _autoTimer?.cancel();
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

  // 1. Отправка PIN-кода на свой email
  Future<void> _sendCustomEmailPin() async {
    final email = _customEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Введите корректный адрес электронной почты';
      });
      return;
    }

    setState(() {
      _isSendingPin = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/session/start'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _sessionId = data['sessionId'];
          _activeEmail = email;
          _customEmailSentTo = email;
          _pinSent = true;
          _isSendingPin = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Код подтверждения отправлен на $email'),
              backgroundColor: Colors.blue.shade700,
            ),
          );
        }
      } else {
        throw Exception(data['error'] ?? 'Не удалось отправить код');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingPin = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  // 2. Подтверждение PIN-кода
  Future<void> _verifyPinCode() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      setState(() {
        _errorMessage = 'Введите 6-значный код из письма';
      });
      return;
    }
    if (_sessionId == null) return;

    setState(() {
      _isVerifyingPin = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/session/verify-pin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sessionId': _sessionId,
              'pin': pin,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _captchaBase64 = data['captcha'];
          _isVerifyingPin = false;
        });
      } else {
        throw Exception(data['error'] ?? 'Неверный код подтверждения');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingPin = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  // 3. Автоматическая генерация временной почты
  Future<void> _startAutoRegistration() async {
    _autoTimer?.cancel();
    setState(() {
      _isInitializingAuto = true;
      _autoSecondsElapsed = 0;
      _errorMessage = null;
    });

    _autoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _autoSecondsElapsed++;
        });
      }
    });

    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/api/session'))
          .timeout(const Duration(seconds: 140));

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _sessionId = data['sessionId'];
          _activeEmail = data['email'];
          _captchaBase64 = data['captcha'];
          _isInitializingAuto = false;
        });
      } else {
        throw Exception(data['error'] ?? 'Не удалось получить код на временную почту');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializingAuto = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    } finally {
      _autoTimer?.cancel();
    }
  }

  Future<void> _reloadCaptcha() async {
    if (_sessionId == null) return;
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/api/captcha?sessionId=$_sessionId'))
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (data['success'] == true && data['captcha'] != null) {
        setState(() {
          _captchaBase64 = data['captcha'];
          _captchaController.clear();
        });
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

      if (data['success'] == true) {
        final userData = {
          'email': data['email'] ?? _activeEmail,
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
          widget.onLoginStateChanged?.call();
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
        String msg = e.toString().replaceAll('Exception:', '').trim();
        if (msg.contains('<html') || msg.contains('<!DOCTYPE')) {
          msg = 'Сервер Инфинити отклонил регистрацию. Проверьте правильность введенных данных или обновите капчу.';
        }
        setState(() {
          _isSubmitting = false;
          _errorMessage = msg;
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
        _pinSent = false;
        _activeEmail = null;
        _captchaBase64 = null;
      });
      widget.onLoginStateChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = _isLoadingUser
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: widget.showAppBar ? 20 : 120,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _savedUser != null
                    ? _buildProfileCard()
                    : _captchaBase64 != null
                        ? _buildRegistrationForm()
                        : _buildInitialCard(),
              ),
            ),
          );

    if (!widget.showAppBar) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        centerTitle: true,
      ),
      body: bodyContent,
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
                  child: const Icon(Icons.person, size: 32, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Партнер Инфинити',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildInfoRow('Телефон', phone.isNotEmpty ? '+7 $phone' : '—'),
            const SizedBox(height: 12),
            _buildInfoRow('Город', city.isNotEmpty ? city : '—'),
            const SizedBox(height: 12),
            _buildInfoRow('E-mail (логин)', email, isCopyable: true),
            const SizedBox(height: 12),
            _buildInfoRow('Пароль', password, isCopyable: true),
            if (ticket.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow('ID тикета', ticket, isCopyable: true),
            ],
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Кабинет Инфинити'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      final url = Uri.parse('https://infinity-mlm.com/user/login');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.outlined(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  tooltip: 'Выйти из аккаунта',
                  onPressed: _logout,
                ),
              ],
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_circle, size: 48, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Регистрация в НПК ИНФИНИТИ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Создайте официальный партнерский аккаунт прямо из приложения.',
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

            // Вариант 1: Свой Email (рекомендуется)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Регистрация на ваш E-mail',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'На вашу почту мгновенно придет 6-значный код подтверждения.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _customEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Ваш E-mail',
                      hintText: 'example@mail.ru',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (!_pinSent) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton.icon(
                        icon: _isSendingPin
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(_isSendingPin ? 'Отправка кода...' : 'Получить код активации'),
                        onPressed: (_isSendingPin || _isInitializingAuto) ? null : _sendCustomEmailPin,
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Код отправлен на $_customEmailSentTo',
                              style: const TextStyle(fontSize: 12, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: '6-значный код из письма',
                        prefixIcon: const Icon(Icons.pin),
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed: _isVerifyingPin ? null : _verifyPinCode,
                        child: _isVerifyingPin
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Подтвердить код'),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('или', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),

            // Вариант 2: Автоматический временный ящик
            OutlinedButton.icon(
              icon: _isInitializingAuto
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_mode_rounded, size: 18),
              label: Text(
                _isInitializingAuto
                    ? 'Ожидание кода: $_autoSecondsElapsed сек (до 2 мин)...'
                    : 'Сгенерировать временный e-mail (авто)',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: (_isInitializingAuto || _isSendingPin) ? null : _startAutoRegistration,
            ),
            if (_isInitializingAuto) ...[
              const SizedBox(height: 8),
              Text(
                'Сервер ожидает письмо от НПК ИНФИНИТИ (обычно занимает 60–90 сек). Пожалуйста, не закрывайте страницу...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
              ),
            ],
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user, color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'E-mail подтвержден!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          _activeEmail ?? '',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),

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
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Фамилия *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Укажите фамилию' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Имя *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Укажите имя' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _patronymicController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Отчество (необязательно)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Город *',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Укажите город' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Телефон *',
                  hintText: '9001234567',
                  prefixText: '+7 ',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Укажите номер телефона';
                  final digits = v.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10) return 'Минимум 10 цифр';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Пароль для кабинета *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Придумайте пароль';
                  if (v.length < 4) return 'Минимум 4 символа';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _sponsorController,
                decoration: const InputDecoration(
                  labelText: 'ID / логин спонсора (необязательно)',
                  prefixIcon: Icon(Icons.group_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Блок капчи
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (captchaBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              captchaBytes,
                              height: 48,
                              fit: BoxFit.contain,
                            ),
                          )
                        else
                          const SizedBox(
                            width: 100,
                            height: 48,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Обновить код с картинки',
                          onPressed: _reloadCaptcha,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _captchaController,
                      decoration: const InputDecoration(
                        labelText: 'Символы с картинки *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите код с картинки' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
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

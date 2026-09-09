import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/infinity_auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final InfinityAuthService _authService = InfinityAuthService();

  // Текущий шаг регистрации: 1 (Email), 2 (Код), 3 (Анкета), 4 (Успех)
  int _currentStep = 1;
  bool _isLoading = false;
  String? _errorMessage;
  String _autoStatus = '';
  bool _isAutoMode = false;

  // Данные сессии
  String _sessionGuid = '';

  // Контроллеры шага 1
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _sponsorController = TextEditingController();

  // Контроллеры шага 2 (Код)
  final TextEditingController _pinController = TextEditingController();
  Timer? _countdownTimer;
  int _resendCountdown = 90;
  bool _canResend = false;

  // Контроллеры шага 3 (Анкета)
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _agreeTerms = true;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _sponsorController.dispose();
    _pinController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _resendCountdown = 90;
      _canResend = false;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 1) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  // --- АВТОМАТИЗАЦИЯ: Регистрация через Temp-Mail в 1 клик ---
  Future<void> _handleAutoTempMail() async {
    if (kIsWeb) {
      await launchUrl(
        Uri.parse('https://temp-mail.io/ru/'),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сервис Temp-Mail.io открыт в новой вкладке! Скопируйте созданный email и вставьте в поле ниже.',
          ),
          backgroundColor: Color(0xFF2563EB),
          duration: Duration(seconds: 6),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isAutoMode = true;
      _errorMessage = null;
      _autoStatus = 'Генерируем временный почтовый ящик...';
    });

    final tempEmail = await _authService.createTempEmail();
    if (tempEmail == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isAutoMode = false;
        _errorMessage = 'Не удалось подключиться к сервису Temp-Mail';
      });
      return;
    }

    _emailController.text = tempEmail;

    if (!mounted) return;
    setState(() {
      _autoStatus = 'Отправляем запрос на сайт Инфинити...';
    });

    final result = await _authService.sendEmailPin(tempEmail);
    if (!mounted) return;

    if (result.success && result.guid != null) {
      _sessionGuid = result.guid!;
      setState(() {
        _currentStep = 2;
        _errorMessage = null;
      });
      _startTimer();

      // Автоматический перехват входящего письма с кодом
      _startAutoPollPin(tempEmail);
    } else {
      setState(() {
        _isLoading = false;
        _isAutoMode = false;
        _errorMessage = result.message ?? 'Ошибка при отправке запроса';
      });
    }
  }

  Future<void> _startAutoPollPin(String email) async {
    setState(() {
      _autoStatus = 'Ожидаем входящее письмо от Инфинити (~1-2 мин)...';
    });

    final extractedCode = await _authService.pollTempMailForPin(
      email,
      timeout: const Duration(minutes: 3),
      onStatusUpdate: (status) {
        if (mounted) {
          setState(() {
            _autoStatus = status;
          });
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (extractedCode != null) {
      _pinController.text = extractedCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Код $extractedCode автоматически получен из письма!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      // Автоматически переходим к шагу 3
      _handleVerifyPin();
    } else {
      setState(() {
        _autoStatus =
            'Код пока не поступил. Вы можете проверить почту на temp-mail.io вручную или нажать повторить.';
      });
    }
  }

  // --- ШАГ 1: Запрос кода на Email (ручной ввод) ---
  Future<void> _handleSendPin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() {
        _errorMessage = 'Введите корректный адрес электронной почты';
      });
      return;
    }

    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: email));
      await launchUrl(
        Uri.parse(
            'https://infinity-mlm.com/user/registrationemailconfirm?AliasName='),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      setState(() {
        _currentStep = 2;
        _errorMessage = null;
      });
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Email $email скопирован в буфер! Открыта форма Инфинити — вставьте email и нажмите «Получить код».',
          ),
          backgroundColor: const Color(0xFF2563EB),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _autoStatus = '';
    });

    final result = await _authService.sendEmailPin(email);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (result.success && result.guid != null) {
      _sessionGuid = result.guid!;
      setState(() {
        _currentStep = 2;
        _errorMessage = null;
      });
      _startTimer();

      // Если почта из temp-mail.io, включаем автоматический опрос
      if (email.contains('ozsaip.com') ||
          email.contains('yzcalo.com') ||
          email.contains('lnovic.com') ||
          email.contains('ruutukf.com') ||
          email.contains('gmeenramy.com') ||
          email.contains('olipii.com') ||
          email.contains('ooynib.com')) {
        _startAutoPollPin(email);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Запрос отправлен! Доставка письма занимает 1–2 мин.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      setState(() {
        _errorMessage = result.message ?? 'Ошибка при отправке кода';
      });
    }
  }

  // --- ШАГ 2: Проверка кода ---
  Future<void> _handleVerifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() {
        _errorMessage = 'Введите проверочный код из письма';
      });
      return;
    }

    if (kIsWeb) {
      setState(() {
        _currentStep = 3;
        _errorMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Код принят! Переходим к заполнению анкеты.'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.verifyEmailPin(
      pin: pin,
      guid: _sessionGuid,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      setState(() {
        _currentStep = 3;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = result.message ?? 'Неверный код подтверждения';
      });
    }
  }

  // --- ШАГ 3: Завершение регистрации ---
  Future<void> _handleCompleteRegistration() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (firstName.isEmpty) {
      setState(() => _errorMessage = 'Укажите ваше имя');
      return;
    }
    if (lastName.isEmpty) {
      setState(() => _errorMessage = 'Укажите вашу фамилию');
      return;
    }
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _errorMessage = 'Укажите номер телефона');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Пароль должен быть не менее 6 символов');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Пароли не совпадают');
      return;
    }
    if (!_agreeTerms) {
      setState(
          () => _errorMessage = 'Необходимо согласиться с условиями сервиса');
      return;
    }

    if (kIsWeb) {
      setState(() {
        _currentStep = 4; // Успех
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.completeRegistration(
      email: _emailController.text.trim(),
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      password: password,
      sponsorId: _sponsorController.text.trim().isNotEmpty
          ? _sponsorController.text.trim()
          : null,
      guid: _sessionGuid,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      setState(() {
        _currentStep = 4; // Успех
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = result.message ?? 'Ошибка при создании аккаунта';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация партнёра'),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Верхний логотип / заголовок
              _buildHeader(theme),
              const SizedBox(height: 16),

              // Уведомление для Web-версии
              if (kIsWeb) _buildWebNotice(theme),

              // Индикатор шагов (1 - 2 - 3)
              if (_currentStep < 4) _buildStepProgress(theme),
              const SizedBox(height: 24),

              // Сообщение об ошибке
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Контент текущего шага
              if (_currentStep == 1) _buildStep1Email(theme),
              if (_currentStep == 2) _buildStep2Pin(theme),
              if (_currentStep == 3) _buildStep3Details(theme),
              if (_currentStep == 4) _buildStep4Success(theme),
            ],
          ),
        ),
      ),
    );
  }

  // Заголовок карточки
  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade800,
            Colors.blue.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group_add_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'НПК «ИНФИНИТИ»',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Единая регистрация в MLM-системе',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Информационный блок для браузерной версии (GitHub Pages)
  Widget _buildWebNotice(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hub_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Быстрый доступ к сервисам Инфинити',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'В браузере для моментальной регистрации партнёра рекомендуем открыть официальную форму сайта и сервис временной почты:',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF047857), height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  launchUrl(
                    Uri.parse('https://infinity-mlm.com/user/registrationemailconfirm?AliasName='),
                    mode: LaunchMode.externalApplication,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text(
                  'Сайт Инфинити (Регистрация)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  launchUrl(
                    Uri.parse('https://temp-mail.io/ru/'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.mark_email_read_outlined, size: 16),
                label: const Text(
                  'Temp-Mail.io (Временная почта)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Индикатор шагов
  Widget _buildStepProgress(ThemeData theme) {
    return Row(
      children: [
        _buildStepBadge(1, 'Email', _currentStep >= 1, _currentStep == 1),
        Expanded(
          child: Container(
            height: 3,
            color: _currentStep >= 2 ? Colors.blue : Colors.grey.shade300,
          ),
        ),
        _buildStepBadge(2, 'Код', _currentStep >= 2, _currentStep == 2),
        Expanded(
          child: Container(
            height: 3,
            color: _currentStep >= 3 ? Colors.blue : Colors.grey.shade300,
          ),
        ),
        _buildStepBadge(3, 'Анкета', _currentStep >= 3, _currentStep == 3),
      ],
    );
  }

  Widget _buildStepBadge(
      int step, String label, bool isCompleted, bool isCurrent) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent
                ? Colors.blue
                : (isCompleted ? const Color(0xFF10B981) : Colors.grey.shade300),
          ),
          child: Center(
            child: isCompleted && !isCurrent
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isCurrent || isCompleted
                          ? Colors.white
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? Colors.blue : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // --- ШАГ 1: Почта и Спонсор ---
  Widget _buildStep1Email(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Шаг 1: Электронная почта',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'На этот адрес придёт 6-значный проверочный код. Сервер отправляет письмо в течение 1–2 минут.',
              style: TextStyle(fontSize: 13, color: theme.hintColor),
            ),
            const SizedBox(height: 18),

            // Кнопка быстрой авто-регистрации через Temp-Mail
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Быстрая регистрация (авто-код)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Приложение автоматически создаст временную почту на temp-mail.io, отправит запрос и перехватит код из письма!',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleAutoTempMail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isLoading && _isAutoMode
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.flash_on, size: 18),
                    label: Text(
                      _isLoading && _isAutoMode
                          ? _autoStatus
                          : (kIsWeb
                              ? 'Создать временную почту на Temp-Mail.io'
                              : 'Создать почту и получить код в 1 клик'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('или ввести свою почту',
                      style: TextStyle(fontSize: 12, color: theme.hintColor)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 16),

            // Email
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Ваш Email *',
                hintText: 'example@mail.ru или с temp-mail.io',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    launchUrl(
                      Uri.parse('https://temp-mail.io/ru/'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.mark_email_read_outlined,
                      size: 15, color: Color(0xFF0F766E)),
                  label: const Text(
                    'Получить временную почту на Temp-Mail.io',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F766E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Спонсор (необязательно)
            TextField(
              controller: _sponsorController,
              decoration: InputDecoration(
                labelText: 'ID или Логин наставника (спонсора)',
                hintText: 'Если есть пригласитель',
                helperText: 'Оставьте пустым, если у вас нет наставника',
                prefixIcon: const Icon(Icons.person_pin_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Кнопка отправки кода вручную
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSendPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading && !_isAutoMode
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      kIsWeb
                          ? 'Получить код (открыть Инфинити)'
                          : 'Получить код подтверждения',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),

            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  launchUrl(
                    Uri.parse('https://infinity-mlm.com/user/registration'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.open_in_browser, size: 16),
                label: const Text(
                  'Открыть форму напрямую на сайте Инфинити',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ШАГ 2: Ввод кода ---
  Widget _buildStep2Pin(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Шаг 2: Введите код из письма',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: theme.hintColor),
                children: [
                  const TextSpan(text: 'Письмо отправлено на адрес:\n'),
                  TextSpan(
                    text: _emailController.text,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Подсказка о доставке
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Почтовая очередь Инфинити отправляет код за 1–2 мин. Обязательно проверьте «Спам».',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),

            if (_autoStatus.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _autoStatus,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Поле ввода PIN-кода
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 10,
              ),
              decoration: InputDecoration(
                hintText: '• • • • • •',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Таймер повторной отправки
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_canResend) ...[
                  const Icon(Icons.timer_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Повторный запрос через $_resendCountdown сек',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ] else ...[
                  TextButton.icon(
                    onPressed: _handleSendPin,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Отправить код повторно'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Кнопка быстрого перехода в Temp-Mail
            OutlinedButton.icon(
              onPressed: () {
                launchUrl(
                  Uri.parse('https://temp-mail.io/ru/'),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.mark_email_read_outlined,
                  size: 16, color: Color(0xFF0F766E)),
              label: const Text(
                'Проверить входящие на Temp-Mail.io',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F766E),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0F766E)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Кнопка подтверждения
            ElevatedButton(
              onPressed: _isLoading ? null : _handleVerifyPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Подтвердить код',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 10),

            // Изменить email
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                  _pinController.clear();
                  _errorMessage = null;
                  _autoStatus = '';
                });
              },
              child: const Text('Изменить email'),
            ),
          ],
        ),
      ),
    );
  }

  // --- ШАГ 3: Анкета партнёра ---
  Widget _buildStep3Details(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Шаг 3: Данные партнёра',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Заполните контактные данные для создания личного кабинета.',
              style: TextStyle(fontSize: 13, color: theme.hintColor),
            ),
            const SizedBox(height: 20),

            // Имя
            TextField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: 'Имя *',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Фамилия
            TextField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: 'Фамилия *',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Телефон
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Номер телефона *',
                hintText: '+7 (999) 000-00-00',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Пароль
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Пароль (мин. 6 символов) *',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Подтверждение пароля
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Повторите пароль *',
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Чекбокс согласия
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreeTerms,
                  onChanged: (val) {
                    setState(() => _agreeTerms = val ?? true);
                  },
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Я согласен с правилами сервиса и обработкой персональных данных',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Кнопка создания аккаунта
            ElevatedButton(
              onPressed: _isLoading ? null : _handleCompleteRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Завершить регистрацию',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ШАГ 4: Поздравление и успех ---
  Widget _buildStep4Success(ThemeData theme) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Поздравляем с регистрацией!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ваш партнёрский аккаунт в единой системе НПК «Инфинити» успешно создан. Теперь вы можете войти в личный кабинет, оформлять заказы по дистрибьюторским ценам и копить баллы.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_circle, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Логин для входа:',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          _emailController.text,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _emailController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Перейти ко входу',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                launchUrl(
                  Uri.parse('https://infinity-mlm.com/user/login'),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('Открыть сайт Инфинити'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

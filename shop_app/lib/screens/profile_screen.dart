import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cabinet/accounts_screen.dart';
import 'cabinet/bonus_report_screen.dart';
import 'cabinet/downline_screen.dart';
import 'cabinet/invited_screen.dart';
import 'cabinet/sales_history_screen.dart';
import 'cabinet/upline_screen.dart';
import 'cabinet/edit_profile_screen.dart';

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
  bool _isSubmitting = false;

  String? _sessionId;
  String? _activeEmail;
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

  // Вход в аккаунт
  final _loginFormKey = GlobalKey<FormState>();
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscurePassword = true;
  bool _isLoggingIn = false;
  String? _loginErrorMessage;

  // Поиск спонсора
  String? _sponsorFio;
  bool _isCheckingSponsor = false;
  String? _sponsorError;
  Timer? _sponsorDebounce;

  @override
  void initState() {
    super.initState();
    _loadSavedUser();
  }

  @override
  void dispose() {
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _lastNameController.dispose();
    _firstNameController.dispose();
    _patronymicController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _sponsorController.dispose();
    _captchaController.dispose();
    _autoTimer?.cancel();
    _sponsorDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('saved_auth_user');
      if (userStr != null && userStr.isNotEmpty) {
        final parsed = jsonDecode(userStr);
        setState(() {
          _savedUser = parsed;
        });
        // Auto-refresh cabinet metrics if missing referral link, stats, or full FIO
        if (parsed['referralLink'] == null ||
            parsed['stats'] == null ||
            parsed['partnerFio'] == null ||
            (parsed['partnerFio'] as String).isEmpty) {
          _refreshCabinetStats();
        }
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

  bool _isRefreshingCabinet = false;

  Future<void> _refreshCabinetStats() async {
    if (_savedUser == null) return;
    setState(() => _isRefreshingCabinet = true);
    try {
      final ticket = _savedUser!['ticket'] ?? _savedUser!['partnersTicket'] ?? '';
      final guid = _savedUser!['partnersGuid'] ?? '';
      final utckt = _savedUser!['usersTicket'] ?? _savedUser!['utckt'] ?? '';
      final login = _savedUser!['login'] ?? _savedUser!['email'] ?? _savedUser!['partnerId'] ?? '';
      final password = _savedUser!['password'] ?? '';

      final url = Uri.parse(
        '$apiBaseUrl/api/cabinet?ticket=$ticket&guid=$guid&utckt=$utckt&login=${Uri.encodeComponent(login)}&password=${Uri.encodeComponent(password)}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 25));
      if (!mounted) return;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true) {
        final updated = Map<String, dynamic>.from(_savedUser!);
        if (data['referralLink'] != null && (data['referralLink'] as String).isNotEmpty) {
          updated['referralLink'] = data['referralLink'];
        }
        if (data['partnersGuid'] != null && (data['partnersGuid'] as String).isNotEmpty) {
          updated['partnersGuid'] = data['partnersGuid'];
        }
        if (data['warehouse'] != null && (data['warehouse'] as String).isNotEmpty) {
          updated['warehouse'] = data['warehouse'];
        }
        if (data['partnerId'] != null && (data['partnerId'] as String).isNotEmpty) {
          updated['partnerId'] = data['partnerId'];
        }
        if (data['partnerName'] != null && (data['partnerName'] as String).isNotEmpty) {
          updated['partnerName'] = data['partnerName'];
        }
        if (data['partnerFio'] != null && (data['partnerFio'] as String).isNotEmpty) {
          updated['partnerFio'] = data['partnerFio'];
        }
        if (data['ticket'] != null && (data['ticket'] as String).isNotEmpty) {
          updated['ticket'] = data['ticket'];
          updated['partnersTicket'] = data['ticket'];
        }
        if (data['usersTicket'] != null && (data['usersTicket'] as String).isNotEmpty) {
          updated['usersTicket'] = data['usersTicket'];
          updated['utckt'] = data['usersTicket'];
        }
        if (data['stats'] != null) {
          updated['stats'] = data['stats'];
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_auth_user', jsonEncode(updated));
        setState(() {
          _savedUser = updated;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing cabinet stats: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshingCabinet = false);
      }
    }
  }

  // Вход в аккаунт
  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final username = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text;

    setState(() {
      _isLoggingIn = true;
      _loginErrorMessage = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 40));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true && data['user'] != null) {
        final userData = Map<String, dynamic>.from(data['user']);
        userData['password'] = password;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_auth_user', jsonEncode(userData));
        if (mounted) {
          setState(() {
            _savedUser = userData;
            _isLoggingIn = false;
          });
          widget.onLoginStateChanged?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Вход выполнен! Добро пожаловать, ${_savedUser?['partnerFio'] ?? _savedUser?['partnerName'] ?? _savedUser?['partnerId'] ?? username}'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } else {
        throw Exception(data['error'] ?? 'Неверный логин или пароль');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
          _loginErrorMessage = e.toString().replaceAll('Exception:', '').trim();
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
          .timeout(const Duration(seconds: 200));

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

  void _onSponsorChanged(String value) {
    _sponsorDebounce?.cancel();
    final trimmed = value.trim();
    final cleaned = trimmed.replaceFirst(RegExp(r'^(?:id|ид|номер)[\s:#№-]*', caseSensitive: false), '').trim();

    if (cleaned.isEmpty) {
      setState(() {
        _isCheckingSponsor = false;
        _sponsorFio = null;
        _sponsorError = null;
      });
      return;
    }

    // While typing, reset previous error and fio to avoid flashing "Данные не найдены"
    setState(() {
      _sponsorFio = null;
      _sponsorError = null;
    });

    _sponsorDebounce = Timer(const Duration(milliseconds: 700), () {
      _checkSponsor(cleaned);
    });
  }

  Future<void> _checkSponsor(String query) async {
    final cleaned = query.replaceFirst(RegExp(r'^(?:id|ид|номер)[\s:#№-]*', caseSensitive: false), '').trim();
    if (cleaned.isEmpty) return;

    setState(() {
      _isCheckingSponsor = true;
      _sponsorFio = null;
      _sponsorError = null;
    });

    try {
      final sessParam = _sessionId != null ? '&sessionId=$_sessionId' : '';
      final response = await http
          .get(Uri.parse('$apiBaseUrl/api/sponsor?sid=${Uri.encodeComponent(cleaned)}$sessParam'))
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true &&
          data['sponsorFio'] != null &&
          (data['sponsorFio'] as String).isNotEmpty) {
        setState(() {
          _isCheckingSponsor = false;
          _sponsorFio = (data['sponsorFio'] as String).trim();
          _sponsorError = null;
        });
      } else {
        setState(() {
          _isCheckingSponsor = false;
          _sponsorFio = null;
          _sponsorError = data['error'] ?? 'Данные не найдены';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingSponsor = false;
        _sponsorFio = null;
        _sponsorError = 'Ошибка проверки спонсора';
      });
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
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_sessionId == null) {
      setState(() {
        _errorMessage = 'Сессия устарела или не найдена. Начните регистрацию заново.';
      });
      return;
    }

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
        final partnerId = (data['partnerId'] ?? '').toString().trim();
        final email = (data['email'] ?? _activeEmail ?? '').toString().trim();
        final password = _passwordController.text.trim();

        final sponsorVal = (data['sponsor'] ?? _sponsorController.text.trim()).toString().trim();
        final sponsorFioVal = (data['sponsorFio'] ?? _sponsorFio ?? '').toString().trim();

        final referralLink = (data['referralLink'] ?? '').toString().trim();
        final partnersGuid = (data['partnersGuid'] ?? '').toString().trim();
        final warehouse = (data['warehouse'] ?? '★ Главный').toString().trim();
        final partnerName = (data['partnerName'] ?? '').toString().trim();
        final stats = data['stats'] is Map ? Map<String, dynamic>.from(data['stats']) : null;

        final userData = {
          'email': email,
          'password': password,
          'lastName': _lastNameController.text.trim(),
          'firstName': _firstNameController.text.trim(),
          'partnerName': partnerName,
          'city': _cityController.text.trim(),
          'phone': _phoneController.text.trim(),
          'sponsor': sponsorVal,
          'sponsorFio': sponsorFioVal,
          'ticket': (data['ticket'] ?? '').toString().trim(),
          'partnerId': partnerId,
          'partnersGuid': partnersGuid,
          'referralLink': referralLink,
          'warehouse': warehouse,
          'stats': stats,
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

          _showRegistrationSuccessDialog(
            partnerId: partnerId,
            email: email,
            password: password,
            sponsorFio: sponsorFioVal,
            referralLink: referralLink,
            warehouse: warehouse,
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
        _activeEmail = null;
        _captchaBase64 = null;
      });
      widget.onLoginStateChanged?.call();
    }
  }

  void _resetRegistration() {
    _sponsorDebounce?.cancel();
    setState(() {
      _sessionId = null;
      _activeEmail = null;
      _captchaBase64 = null;
      _errorMessage = null;
      _captchaController.clear();
      _sponsorController.clear();
      _sponsorFio = null;
      _sponsorError = null;
      _isCheckingSponsor = false;
      _isSubmitting = false;
    });
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

  void _showRegistrationSuccessDialog({
    required String partnerId,
    required String email,
    required String password,
    String? sponsorFio,
    String? referralLink,
    String? warehouse,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Поздравляем с регистрацией!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Вы успешно зарегистрированы в НПК ИНФИНИТИ!',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (sponsorFio != null && sponsorFio.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.group, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ваш спонсор: $sponsorFio',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (partnerId.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ваш ID номер партнера:',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            partnerId,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              letterSpacing: 1.5,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: partnerId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('ID партнера скопирован'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.copy, size: 20, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (referralLink != null && referralLink.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.share_outlined, size: 16, color: Colors.purple),
                          const SizedBox(width: 6),
                          const Text(
                            'Ваша реферальная ссылка:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        referralLink,
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.copy, size: 14),
                              label: const Text('Копировать', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.purple,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                side: const BorderSide(color: Colors.purple),
                              ),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: referralLink));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Реферальная ссылка скопирована'), duration: Duration(seconds: 1)),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.share, size: 14),
                              label: const Text('Поделиться', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                              onPressed: () {
                                Share.share('Присоединяйтесь к НПК ИНФИНИТИ: $referralLink');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (warehouse != null && warehouse.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.storefront_outlined, size: 16, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            'Склад: $warehouse',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Логин: $email',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: email));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Логин скопирован'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.copy, size: 16, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Пароль: $password',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: password));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Пароль скопирован'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.copy, size: 16, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Все данные сохранены в вашем профиле приложения.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('В кабинет'),
            onPressed: () async {
              final url = Uri.parse('https://infinity-mlm.com/user/myaccount');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Отлично'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final partnerFio = (_savedUser!['partnerFio'] ?? _savedUser!['fio'] ?? '').toString().trim();
    final partnerName = (_savedUser!['partnerName'] ?? '').toString().trim();
    final combinedFio = '${_savedUser!['lastName'] ?? ''} ${_savedUser!['firstName'] ?? ''} ${_savedUser!['patronymic'] ?? ''}'.trim();
    final partnerId = (_savedUser!['partnerId'] ?? '').toString().trim();

    String displayFio = '';
    if (partnerFio.isNotEmpty) {
      displayFio = partnerFio;
    } else if (combinedFio.isNotEmpty) {
      displayFio = combinedFio;
    } else if (partnerName.isNotEmpty) {
      displayFio = partnerName;
    } else if (partnerId.isNotEmpty) {
      displayFio = 'Партнер #$partnerId';
    } else {
      displayFio = 'Партнер Инфинити';
    }

    final referralLink = (_savedUser!['referralLink'] ?? '').toString().trim();
    final partnersGuid = (_savedUser!['partnersGuid'] ?? '').toString().trim();
    final effectiveRefLink = referralLink.isNotEmpty
        ? referralLink
        : (partnersGuid.isNotEmpty
            ? 'https://infinity-mlm.com/user/registration?ref=$partnersGuid&warehouse=1'
            : '');
    final stats = _savedUser!['stats'] is Map ? Map<String, dynamic>.from(_savedUser!['stats']) : null;
    final partnersCount = stats?['partnersCount'] ?? '0';
    final partnersCountIncrease = stats?['partnersCountIncrease'] ?? '0%';
    final lop = stats?['lop'] ?? '0.00';
    final lopIncrease = stats?['lopIncrease'] ?? '0%';
    final bonus = stats?['bonus'] ?? '0 ₽';
    final bonusIncrease = stats?['bonusIncrease'] ?? '0%';
    final stock = stats?['stock'] ?? '0 Бонус';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header with Avatar, Name, Refresh
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, size: 30, color: Colors.blue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    displayFio,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: _isRefreshingCabinet
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  tooltip: 'Обновить данные кабинета',
                  onPressed: _isRefreshingCabinet ? null : _refreshCabinetStats,
                ),
              ],
            ),
            const Divider(height: 28),

            // 2. Partner ID block
            if (partnerId.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ваш ID партнера',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          partnerId,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blue),
                      tooltip: 'Скопировать ID партнера',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: partnerId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ID партнера скопирован'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 3. Referral Program Card ("Ссылки для новых участников")
            if (effectiveRefLink.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade50,
                      Colors.purple.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.group_add, color: Colors.purple, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Ссылки для новых участников',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Реферальная ссылка на регистрацию:',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        effectiveRefLink,
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('Скопировать', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.purple,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              side: const BorderSide(color: Colors.purple),
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: effectiveRefLink));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Реферальная ссылка скопирована'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.share, size: 14),
                            label: const Text('Поделиться', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            onPressed: () {
                              Share.share('Присоединяйтесь к НПК ИНФИНИТИ: $effectiveRefLink');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. Cabinet Metrics / Widgets (4 cards: РЕКРУТЫ, БОНУС, ЛО, ОСТАТОК)
            Row(
              children: [
                const Icon(Icons.dashboard_outlined, size: 16, color: Colors.black87),
                const SizedBox(width: 6),
                const Text(
                  'Показатели личного кабинета',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.work_outline,
                    color: Colors.blue,
                    title: 'РЕКРУТЫ',
                    value: partnersCount,
                    subtitle: 'Разница: $partnersCountIncrease',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => DownlineScreen(user: _savedUser!, apiBaseUrl: apiBaseUrl),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.card_giftcard,
                    color: Colors.orange.shade800,
                    title: 'БОНУС',
                    value: bonus,
                    subtitle: 'Разница: $bonusIncrease',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => BonusReportScreen(user: _savedUser!, apiBaseUrl: apiBaseUrl),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.pie_chart,
                    color: Colors.teal,
                    title: 'ЛО (ЛИЧНЫЙ ОБЪЕМ)',
                    value: lop,
                    subtitle: 'Разница: $lopIncrease',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => DownlineScreen(user: _savedUser!, apiBaseUrl: apiBaseUrl),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.account_balance_wallet,
                    color: Colors.green.shade700,
                    title: 'ОСТАТОК',
                    value: stock,
                    subtitle: 'Счета и баланс',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => AccountsScreen(user: _savedUser!, apiBaseUrl: apiBaseUrl),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 28),



            // 6. Native MLM Cabinet Sections
            Row(
              children: [
                const Icon(Icons.apps, size: 18, color: Colors.blue),
                const SizedBox(width: 6),
                const Text(
                  'Личный кабинет партнера',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildCabinetQuickLink(
              icon: Icons.account_balance_wallet,
              title: 'Мои счета',
              subtitle: 'Баланс, лицевые счета и история операций',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => AccountsScreen(user: _savedUser!, apiBaseUrl: apiBaseUrl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildCabinetQuickLink(
              icon: Icons.account_tree,
              title: 'Нижестоящие участники (Структура)',
              subtitle: 'Вся глубина команды, поиск, уровни и ЛО',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => DownlineScreen(user: _savedUser!, apiBaseUrl: apiBaseUrl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildCabinetQuickLink(
              icon: Icons.group_add,
              title: 'Лично приглашенные',
              subtitle: 'Партнеры первой линии со связью по телефону и WhatsApp',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => InvitedScreen(user: _savedUser!, apiBaseUrl: apiBaseUrl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildCabinetQuickLink(
              icon: Icons.supervisor_account,
              title: 'Вышестоящие участники (Спонсоры)',
              subtitle: 'Цепочка наставников вплоть до руководства компании',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => UplineScreen(user: _savedUser!, apiBaseUrl: apiBaseUrl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildCabinetQuickLink(
              icon: Icons.emoji_events,
              title: 'Мои вознаграждения',
              subtitle: 'Начисления бонусов по расчетным периодам',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => BonusReportScreen(user: _savedUser!, apiBaseUrl: apiBaseUrl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildCabinetQuickLink(
              icon: Icons.shopping_bag_outlined,
              title: 'История заказов',
              subtitle: 'Накладные, баллы (ЛО), склады и статусы',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => SalesHistoryScreen(user: _savedUser!, apiBaseUrl: apiBaseUrl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildCabinetQuickLink(
              icon: Icons.badge_outlined,
              title: 'Изменение личных данных',
              subtitle: 'Редактирование ФИО, города и смена пароля',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => EditProfileScreen(
                    user: _savedUser!,
                    apiBaseUrl: apiBaseUrl,
                    onProfileUpdated: () {
                      _loadSavedUser();
                      _refreshCabinetStats();
                    },
                  ),
                ),
              ),
            ),
            const Divider(height: 28),

            // 7. Logout button
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.logout, color: Colors.red, size: 18),
                label: const Text('Выйти из аккаунта', style: TextStyle(color: Colors.red)),
                onPressed: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 14, color: color.withValues(alpha: 0.6)),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }
    return content;
  }

  Widget _buildCabinetQuickLink({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
          ],
        ),
      ),
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

            // Кнопка регистрации
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                icon: _isInitializingAuto
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add_rounded, size: 20),
                label: Text(
                  _isInitializingAuto
                      ? 'Ожидание кода: $_autoSecondsElapsed сек (до 3 мин)...'
                      : 'Зарегистрироваться (автоматически)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onPressed: (_isInitializingAuto || _isLoggingIn) ? null : _startAutoRegistration,
              ),
            ),
            if (_isInitializingAuto) ...[
              const SizedBox(height: 10),
              Text(
                'Сервер ожидает код подтверждения от НПК ИНФИНИТИ (до 3 мин). Пожалуйста, не закрывайте страницу...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
              ),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('или войдите в существующий аккаунт', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),

            // Форма входа в аккаунт
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
              ),
              child: Form(
                key: _loginFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.login_rounded, color: Colors.blue.shade700, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Вход в аккаунт',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Для действующих партнеров и зарегистрированных пользователей.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    if (_loginErrorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _loginErrorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _loginUsernameController,
                      decoration: InputDecoration(
                        labelText: 'Логин, ID партнера или E-mail',
                        hintText: 'Например, 23316 или user@mail.ru',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Введите логин, ID или E-mail' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _loginPasswordController,
                      obscureText: _loginObscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_loginObscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _loginObscurePassword = !_loginObscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Введите пароль' : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: _isLoggingIn ? null : _submitLogin,
                        child: _isLoggingIn
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Войти в аккаунт', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          final uri = Uri.parse('https://infinity-mlm.com/user/login?ReturnUrl=%2Fuser%2Fmyaccount');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Text('Забыли пароль? Восстановить на сайте', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      if (_errorMessage!.toLowerCase().contains('устарела') ||
                          _errorMessage!.toLowerCase().contains('не найдена') ||
                          _errorMessage!.toLowerCase().contains('заново')) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _resetRegistration,
                          icon: const Icon(Icons.refresh, size: 16, color: Colors.red),
                          label: const Text(
                            'Начать регистрацию заново',
                            style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ],
                    ],
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
                onChanged: _onSponsorChanged,
                onFieldSubmitted: (val) {
                  _sponsorDebounce?.cancel();
                  _checkSponsor(val);
                },
                decoration: InputDecoration(
                  labelText: 'ID / логин спонсора (необязательно)',
                  hintText: 'Например, 1, 17 или 23316',
                  prefixIcon: const Icon(Icons.group_outlined),
                  suffixIcon: _isCheckingSponsor
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_sponsorController.text.trim().isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_sponsorFio != null && _sponsorFio!.isNotEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(Icons.search, size: 20),
                                    tooltip: 'Проверить спонсора',
                                    onPressed: () {
                                      _sponsorDebounce?.cancel();
                                      _checkSponsor(_sponsorController.text);
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: 'Очистить',
                                  onPressed: () {
                                    _sponsorController.clear();
                                    _onSponsorChanged('');
                                  },
                                ),
                              ],
                            )
                          : null),
                ),
              ),
              if (_isCheckingSponsor) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Поиск спонсора...',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ] else if (_sponsorFio != null && _sponsorFio!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Спонсор: $_sponsorFio',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_sponsorError != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _sponsorError!,
                          style: const TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

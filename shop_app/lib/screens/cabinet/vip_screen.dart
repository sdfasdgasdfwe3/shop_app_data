import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class VipScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String apiBaseUrl;

  const VipScreen({
    super.key,
    required this.user,
    this.apiBaseUrl = 'https://znam.space',
  });

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isVip = false;
  bool _hasPendingRequest = false;
  String? _errorMessage;

  // Tabs: 0: Авто-регистрация, 1: Терминации
  late TabController _tabController;

  // ===================== АВТО-РЕГИСТРАЦИЯ =====================
  bool _isLoadingRegistrations = false;
  List<Map<String, dynamic>> _registrations = [];
  bool _isSubmitting = false;
  Timer? _pollingTimer;

  // Form controllers
  final _sponsorController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _patronymicController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = false;
  String _verifiedSponsorName = '';
  bool _isVerifyingSponsor = false;

  // ===================== АНАЛИЗ ТЕРМИНАЦИЙ =====================
  bool _isLoadingTerminations = false;
  String? _terminationsError;
  String _nextMonthName = '';
  int _totalDownlineCount = 0;
  List<Map<String, dynamic>> _terminatingPartners = [];
  String _terminationsSearch = '';
  bool _onlyFirstLevel = false;
  bool _isAdminUnlocked = false;



  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _phoneController.text = '+7';
    _checkVipStatus();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    _sponsorController.dispose();
    _lastNameController.dispose();
    _firstNameController.dispose();
    _patronymicController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _cleanPartnerId {
    final raw = (widget.user['partnerId'] ?? widget.user['id'] ?? widget.user['login'] ?? widget.user['username'] ?? '').toString();
    return raw.toLowerCase().replaceAll(RegExp(r'^(?:id|ид)[\s:#№-]*', caseSensitive: false), '').trim();
  }

  String get _partnerFio {
    final raw = (widget.user['partnerFio'] ?? widget.user['fio'] ?? widget.user['partnerName'] ?? '').toString();
    return raw.trim();
  }

  String get _partnerPhone {
    return (widget.user['phone'] ?? '').toString().trim();
  }

  String get _ticket {
    return (widget.user['ticket'] ?? widget.user['partnersTicket'] ?? '').toString().trim();
  }

  String get _guid {
    return (widget.user['partnersGuid'] ?? widget.user['guid'] ?? '').toString().trim();
  }

  String get _utckt {
    return (widget.user['utckt'] ?? widget.user['usersTicket'] ?? '').toString().trim();
  }



  Future<void> _checkVipStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pid = _cleanPartnerId;
      final uri = Uri.parse('${widget.apiBaseUrl}/api/vip/status?partnerId=${Uri.encodeComponent(pid)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final isVip = data['isVip'] == true;
          setState(() {
            _isVip = isVip;
            _hasPendingRequest = data['hasPendingRequest'] == true;
            _isLoading = false;
          });

          if (isVip) {
            _loadRegistrations();
            _loadTerminations();
            _verifySponsor(_cleanPartnerId);
          }
          return;
        }
      }
      setState(() {
        _isVip = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось подключиться к серверу проверки прав';
      });
    }
  }

  Future<void> _verifySponsor(String query) async {
    final clean = query.toLowerCase().replaceAll(RegExp(r'^(?:id|ид)[\s:#№-]*', caseSensitive: false), '').trim();
    if (clean.isEmpty) {
      setState(() => _verifiedSponsorName = '');
      return;
    }
    setState(() => _isVerifyingSponsor = true);
    try {
      final res = await http.get(Uri.parse('${widget.apiBaseUrl}/api/sponsor?sponsor=${Uri.encodeComponent(clean)}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true && data['sponsorFio'] != null) {
          setState(() {
            _verifiedSponsorName = data['sponsorFio'].toString();
            _isVerifyingSponsor = false;
          });
          return;
        }
      }
      setState(() {
        _verifiedSponsorName = '';
        _isVerifyingSponsor = false;
      });
    } catch (_) {
      setState(() {
        _verifiedSponsorName = '';
        _isVerifyingSponsor = false;
      });
    }
  }

  // ===================== АВТО-РЕГИСТРАЦИЯ МЕТОДЫ =====================

  Future<void> _loadRegistrations({bool silent = false}) async {
    if (!silent) setState(() => _isLoadingRegistrations = true);
    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/vip/auto-registrations?partnerId=${Uri.encodeComponent(_cleanPartnerId)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true && data['registrations'] is List) {
          if (mounted) {
            setState(() {
              _registrations = List<Map<String, dynamic>>.from(data['registrations']);
              if (!silent) _isLoadingRegistrations = false;
            });
            _checkAndStartPolling();
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[VIP] Error loading registrations: $e');
    }
    if (!silent && mounted) setState(() => _isLoadingRegistrations = false);
  }

  void _checkAndStartPolling() {
    final hasProcessing = _registrations.any((r) => r['status'] == 'processing');
    if (hasProcessing) {
      if (_pollingTimer == null || !_pollingTimer!.isActive) {
        _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          _loadRegistrations(silent: true);
        });
      }
    } else {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  Future<void> _startAutoRegistration() async {
    final lastName = _lastNameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final patronymic = _patronymicController.text.trim();
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();
    final password = _passwordController.text.trim();
    final sponsor = _sponsorController.text.trim();

    if (sponsor.isEmpty) {
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите пароль для входа')),
      );
      return;
    }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите ID спонсора')),
      );
      return;
    }
    if (lastName.isEmpty || firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите фамилию и имя кандидата')),
      );
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите номер телефона')),
      );
      return;
    }
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите город проживания')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'vipPartnerId': _cleanPartnerId,
        'sponsorId': sponsor,
        'lastName': lastName,
        'firstName': firstName,
        'patronymic': patronymic,
        'phone': phone,
        'city': city,
        'password': password,
      };

      final response = await http
          .post(
            Uri.parse('${widget.apiBaseUrl}/api/vip/auto-register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data['success'] == true) {
        final reg = Map<String, dynamic>.from(data['registration'] ?? {});
        setState(() {
          _isSubmitting = false;
          _registrations.removeWhere((r) => r['id'] == reg['id']);
          _registrations.insert(0, reg);
          // Immediately clear candidate inputs so user can type the next person without waiting!
          _lastNameController.clear();
          _firstNameController.clear();
          _patronymicController.clear();
          _phoneController.text = '+7';
          _cityController.clear();
          _passwordController.clear();
          // Sponsor ID remains as-is so subsequent registrations can be under the same sponsor
        });

        _checkAndStartPolling();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0F766E),
              content: Text('Заявка для $lastName $firstName поставлена в очередь регистрации. Вводите следующего!'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text(data['error'] ?? 'Ошибка отправки заявки'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Сбой отправки заявки: $e'),
          ),
        );
      }
    }
  }

  void _showRegistrationSuccessDialog(Map<String, dynamic> reg) {
    final assignedId = reg['partnerId'] ?? '';
    final fio = reg['fio'] ?? '';
    final password = reg['password'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text('Регистрация завершена!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Новый партнер успешно зарегистрирован на сайте НПК Инфинити!',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Присвоенный ID:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16, color: Colors.green),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: assignedId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ID скопирован в буфер обмена')),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    Text(
                      assignedId,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const Divider(height: 16),
                    Text('ФИО: $fio', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Пароль: $password', style: const TextStyle(fontWeight: FontWeight.w600)),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16, color: Colors.black54),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: password));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Пароль скопирован')),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Данные будут храниться в списке ровно 3 дня.',
                style: TextStyle(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Скопировать для партнера'),
              onPressed: () {
                _copyPartnerShareText(reg);
                Navigator.pop(ctx);
              },
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Готово'),
            ),
          ],
        );
      },
    );
  }

  void _copyPartnerShareText(Map<String, dynamic> reg) {
    final assignedId = reg['partnerId'] ?? '';
    final fio = reg['fio'] ?? '';
    final password = reg['password'] ?? '';
    final text = 'Здравствуйте! Ваши данные для входа в НПК «Инфинити»:\n\n'
        'ФИО: $fio\n'
        'Ваш ID номер: $assignedId\n'
        'Пароль: $password\n\n'
        'Сайт для входа: https://infinity-mlm.com';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('Данные для отправки партнеру скопированы!'),
      ),
    );
  }

  Future<void> _deleteRegistration(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: const Text('Вы уверены, что хотите удалить сохраненные учетные данные этой заявки?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/vip/delete-registration'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'partnerId': _cleanPartnerId}),
      );
      setState(() {
        _registrations.removeWhere((item) => item['id'] == id);
      });
    } catch (_) {}
  }

  String _formatTtl(dynamic expiresAt) {
    if (expiresAt == null) return '3 дня';
    final expMs = (expiresAt is num) ? expiresAt.toInt() : int.tryParse(expiresAt.toString()) ?? 0;
    final leftMs = expMs - DateTime.now().millisecondsSinceEpoch;
    if (leftMs <= 0) return 'Истек срок';
    final hours = leftMs ~/ (1000 * 60 * 60);
    final days = hours ~/ 24;
    final remHours = hours % 24;
    if (days > 0) {
      return '$days дн. $remHours ч.';
    }
    final mins = (leftMs ~/ (1000 * 60)) % 60;
    return '$remHours ч. $mins мин.';
  }

  // ===================== АНАЛИЗ ТЕРМИНАЦИЙ МЕТОДЫ =====================

  Future<void> _loadTerminations() async {
    setState(() {
      _isLoadingTerminations = true;
      _terminationsError = null;
    });

    try {
      final pid = _cleanPartnerId;
      final uri = Uri.parse(
        '${widget.apiBaseUrl}/api/vip/terminations?partnerId=${Uri.encodeComponent(pid)}&ticket=${Uri.encodeComponent(_ticket)}&guid=${Uri.encodeComponent(_guid)}&utckt=${Uri.encodeComponent(_utckt)}&login=${Uri.encodeComponent(pid)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true) {
          setState(() {
            _nextMonthName = (data['nextMonthName'] ?? '').toString();
            _totalDownlineCount = (data['totalDownlineCount'] ?? 0) as int;
            _terminatingPartners = List<Map<String, dynamic>>.from(data['partners'] ?? []);
            _isLoadingTerminations = false;
          });
          return;
        } else {
          setState(() {
            _terminationsError = data['error'] ?? 'Не удалось рассчитать терминации';
            _isLoadingTerminations = false;
          });
          return;
        }
      }
      setState(() {
        _terminationsError = 'Ошибка ответа сервера (${res.statusCode})';
        _isLoadingTerminations = false;
      });
    } catch (e) {
      setState(() {
        _terminationsError = 'Сбой сети при анализе структуры: $e';
        _isLoadingTerminations = false;
      });
    }
  }




  // ===================== ПАНЕЛЬ АДМИНИСТРАТОРА =====================

  Future<void> _openAdminPanel() async {
    if (!_isAdminUnlocked) {
      final pinController = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 26),
              SizedBox(width: 10),
              Text('Вход администратора', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Введите пароль администратора для просмотра заявок и управления доступом:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: pinController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Пароль администратора',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () {
                if (pinController.text.trim() == 'alfred2002') {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(backgroundColor: Colors.red, content: Text('Неверный пароль')),
                  );
                }
              },
              child: const Text('Войти'),
            ),
          ],
        ),
      );

      if (ok != true) return;
      _isAdminUnlocked = true;
    }

    if (!mounted) return;
    _showAdminManagementModal();
  }

  void _showAdminManagementModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminPanelModal(
        apiBaseUrl: widget.apiBaseUrl,
        currentUserId: _cleanPartnerId,
        onAccessChanged: () {
          _checkVipStatus();
        },
      ),
    );
  }



  // ===================== BUILD UI =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('VIP - функции', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_rounded, color: Colors.amber),
            tooltip: 'Заявки и управление доступом',
            onPressed: _openAdminPanel,
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Проверка доступа к VIP-разделу...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _checkVipStatus,
                child: const Text('Повторить попытку'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isVip) {
      return _buildAccessDenied();
    }

    return _buildVipHub();
  }

  Widget _buildAccessDenied() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x26FFC107),
                    border: Border.all(color: Colors.amber.shade400, width: 2),
                  ),
                  child: const Icon(Icons.lock_rounded, size: 40, color: Colors.amber),
                ),
                const SizedBox(height: 16),
                const Text(
                  'На данный момент у вас нету доступа к этому разделу',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'ID партнера: $_cleanPartnerId',
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Раздел «VIP - функции» предназначен исключительно для подтвержденных партнеров и лидеров компании.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_hasPendingRequest)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Запрос на рассмотрении',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Администратор проверяет вашу заявку. Доступ откроется сразу после подтверждения.',
                          style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.amber),
                    tooltip: 'Проверить статус',
                    onPressed: _checkVipStatus,
                  ),
                ],
              ),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
              label: const Text(
                'Отправить запрос на подключение администратору',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: _openRequestDialog,
            ),
        ],
      ),
    );
  }

  Future<void> _openRequestDialog() async {
    final commentController = TextEditingController(text: 'Прошу предоставить доступ к VIP-функциям.');
    final fioController = TextEditingController(text: _partnerFio);
    final phoneController = TextEditingController(text: _partnerPhone);

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Запрос на подключение VIP', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              Text('Заявка будет передана администратору', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text('ID партнера: $_cleanPartnerId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fioController,
                      decoration: const InputDecoration(labelText: 'Ваше ФИО', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Телефон для связи', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Сообщение / цель подключения', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: isSending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        isSending ? 'Отправка заявки...' : 'Отправить запрос администратору',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onPressed: isSending
                          ? null
                          : () async {
                              setModalState(() => isSending = true);
                              try {
                                final response = await http
                                    .post(
                                      Uri.parse('${widget.apiBaseUrl}/api/vip/request'),
                                      headers: {'Content-Type': 'application/json'},
                                      body: jsonEncode({
                                        'partnerId': _cleanPartnerId,
                                        'fio': fioController.text.trim(),
                                        'phone': phoneController.text.trim(),
                                        'comment': commentController.text.trim(),
                                      }),
                                    )
                                    .timeout(const Duration(seconds: 10));

                                final data = jsonDecode(utf8.decode(response.bodyBytes));
                                if (data['success'] == true) {
                                  if (ctx.mounted) Navigator.pop(ctx, true);
                                } else {
                                  setModalState(() => isSending = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(data['error'] ?? 'Ошибка отправки')),
                                    );
                                  }
                                }
                              } catch (e) {
                                setModalState(() => isSending = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Сбой сети при отправке заявки')),
                                  );
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (submitted == true && mounted) {
      setState(() => _hasPendingRequest = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Запрос успешно отправлен администратору! Доступ будет активирован после проверки.'),
        ),
      );
    }
  }

  Widget _buildVipHub() {
    return Column(
      children: [
        // VIP Header
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x332563EB), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VIP ПАРТНЕР АКТИВЕН',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _partnerFio.isNotEmpty ? _partnerFio : 'Партнер ID: $_cleanPartnerId',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Полный доступ ко всем VIP-инструментам',
                      style: TextStyle(color: Colors.blue.shade100, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tabs
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF1E3A8A),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF1E3A8A),
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.person_add_alt_1_rounded), text: 'Авто-регистрация'),
              Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Терминации'),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAutoRegistrationTab(),
              _buildTerminationsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ===================== TAB 1: АВТО-РЕГИСТРАЦИЯ =====================

  Widget _buildAutoRegistrationTab() {
    return RefreshIndicator(
      onRefresh: _loadRegistrations,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Registration Form Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Color(0xFF1E3A8A), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Автоматическая регистрация',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Сервер сам решит капчу и зарегистрирует партнера на сайте Инфинити',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Sponsor ID
                  TextField(
                    controller: _sponsorController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'ID Спонсора *',
                      hintText: _cleanPartnerId,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      suffixIcon: _isVerifyingSponsor
                          ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton(
                              icon: const Icon(Icons.search, size: 20),
                              onPressed: () => _verifySponsor(_sponsorController.text),
                            ),
                    ),
                    onChanged: (val) {
                      if (val.length >= 3) _verifySponsor(val);
                    },
                  ),
                  if (_verifiedSponsorName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Спонсор: $_verifiedSponsorName',
                            style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),

                  // FIO
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(labelText: 'Фамилия *', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(labelText: 'Имя *', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _patronymicController,
                          decoration: const InputDecoration(labelText: 'Отчество', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'Город *', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Телефон кандидата *',
                      hintText: '+79991234567',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Пароль для входа *',
                      hintText: 'Введите пароль',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, size: 18),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.rocket_launch_rounded, size: 20),
                    label: Text(
                      _isSubmitting ? 'Отправка заявки...' : 'Запустить автоматическую регистрацию',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: _isSubmitting ? null : _startAutoRegistration,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Зарегистрированные партнеры',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Хранятся 3 дня', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.brown)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isLoadingRegistrations)
            const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
          else if (_registrations.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text('Список пуст', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text(
                    'Создайте заявку в форме выше. После авто-регистрации карточка с ID, ФИО и паролем появится здесь.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            )
          else
            ..._registrations.map((reg) => _buildRegistrationCard(reg)),
        ],
      ),
    );
  }

  Widget _buildRegistrationCard(Map<String, dynamic> reg) {
    final status = (reg['status'] ?? '').toString();
    final isProcessing = status == 'processing';
    final isFailed = status == 'failed';
    final id = (reg['partnerId'] ?? '').toString();
    final fio = (reg['fio'] ?? '').toString();
    final password = (reg['password'] ?? '').toString();
    final sponsor = (reg['sponsorId'] ?? '').toString();
    final phone = (reg['phone'] ?? '').toString();
    final city = (reg['city'] ?? '').toString();
    final expiresAt = reg['expiresAt'];
    final recId = (reg['id'] ?? '').toString();
    final progress = (reg['progress'] ?? '').toString();
    final error = (reg['error'] ?? '').toString();

    // Card border color based on status
    Color borderColor = Colors.grey.shade200;
    if (isProcessing) borderColor = Colors.blue.shade300;
    if (isFailed) borderColor = Colors.red.shade300;
    if (!isProcessing && !isFailed) borderColor = Colors.green.shade300;

    return Card(
      elevation: isProcessing ? 2 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isProcessing ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isProcessing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E3A8A)),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Регистрация на сервере...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  )
                else if (isFailed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 14, color: Colors.red),
                        SizedBox(width: 5),
                        Text('Ошибка регистрации', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  )
                else
                  InkWell(
                    onTap: () => _showRegistrationSuccessDialog(reg),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text('ID: $id', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('ID скопирован')),
                              );
                            },
                            child: const Icon(Icons.copy, size: 14, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isProcessing && !isFailed) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Text(
                          '⏱ ${_formatTtl(expiresAt)}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                      tooltip: 'Удалить из списка',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _deleteRegistration(recId),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Text(fio, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),

            if (isProcessing) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded, size: 15, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        progress.isNotEmpty ? progress : 'Идет автоматическая регистрация в НПК Инфинити...',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (isFailed && error.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  error,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade800, fontWeight: FontWeight.w500),
                ),
              ),
            ],

            if (!isProcessing && !isFailed) ...[
              Row(
                children: [
                  Expanded(
                    child: Text('Пароль: $password', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: password));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Пароль скопирован')),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Icon(Icons.copy, size: 14, color: Colors.black54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            Text('Спонсор: ID $sponsor', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (phone.isNotEmpty || city.isNotEmpty)
              Text('$city ${phone.isNotEmpty ? '• $phone' : ''}', style: const TextStyle(fontSize: 12, color: Colors.black54)),

            if (!isProcessing && !isFailed) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Скопировать данные для партнера', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: () => _copyPartnerShareText(reg),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===================== TAB 2: АНАЛИЗ ТЕРМИНАЦИЙ =====================

  Widget _buildTerminationsTab() {
    if (_isLoadingTerminations) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Анализ структуры и расчет дат терминации...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_terminationsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 10),
              Text(_terminationsError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTerminations,
                child: const Text('Повторить анализ'),
              ),
            ],
          ),
        ),
      );
    }

    // Filter partners by search and level
    final filtered = _terminatingPartners.where((p) {
      if (_onlyFirstLevel && (p['level'] != 1 && p['level'] != '1')) {
        return false;
      }
      if (_terminationsSearch.isEmpty) return true;
      final query = _terminationsSearch.toLowerCase();
      final fio = (p['fio'] ?? '').toString().toLowerCase();
      final id = (p['id'] ?? '').toString().toLowerCase();
      final city = (p['city'] ?? '').toString().toLowerCase();
      final sponsor = (p['sponsorId'] ?? '').toString().toLowerCase();
      final sponsorFio = (p['sponsorFio'] ?? '').toString().toLowerCase();
      return fio.contains(query) || id.contains(query) || city.contains(query) || sponsor.contains(query) || sponsorFio.contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadTerminations,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Warning Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x33DC2626), blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ВНИМАНИЕ: БУДУЩИЕ ТЕРМИНАЦИИ',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                          ),
                          Text(
                            'В следующем месяце (${_nextMonthName.isNotEmpty ? _nextMonthName : 'след. месяц'}): ${_terminatingPartners.length} партн.',
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search and Filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Поиск по ID, ФИО, городу...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _terminationsSearch = val.trim()),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('1-й ур.'),
                selected: _onlyFirstLevel,
                onSelected: (val) => setState(() => _onlyFirstLevel = val),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            'Найдено кандидатов: ${filtered.length} (из $_totalDownlineCount в структуре)',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 8),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                  SizedBox(height: 8),
                  Text('Кандидатов не найдено', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 4),
                  Text(
                    'По указанным фильтрам партнеров под угрозой терминации в следующем месяце не обнаружено.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            )
          else
            ...filtered.map((p) => _buildTerminatingPartnerCard(p)),
        ],
      ),
    );
  }

  Widget _buildTerminatingPartnerCard(Map<String, dynamic> partner) {
    final id = (partner['id'] ?? '').toString();
    final fio = (partner['fio'] ?? '').toString();
    final city = (partner['city'] ?? '').toString();
    final level = partner['level'];
    final sponsorId = (partner['sponsorId'] ?? '').toString();
    final sponsorFio = (partner['sponsorFio'] ?? '').toString();
    final phone = (partner['phone'] ?? '').toString();
    final lastSaleDate = (partner['lastSaleDate'] ?? partner['lastActivityDate'] ?? '').toString();
    final months = partner['monthsWithoutPurchase'] ?? 11;
    final lopCum = partner['lopCumulative'] ?? 0;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFFEE2E2),
                  child: Text(
                    level != null ? 'L$level' : 'L',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fio, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('ID: $id', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: id));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID скопирован')));
                            },
                            child: const Icon(Icons.copy, size: 14, color: Colors.black54),
                          ),
                          if (city.isNotEmpty || phone.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                [if (city.isNotEmpty) '• $city', if (phone.isNotEmpty) '• $phone'].join(' '),
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // Warning Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_busy, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Последняя покупка: $lastSaleDate ($months мес. назад)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Спонсор: ID $sponsorId ${sponsorFio.isNotEmpty ? '($sponsorFio)' : ''}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (lopCum != 0)
                  Text('ЛОП: $lopCum', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
              ],
            ),

          ],
        ),
      ),
    );
  }
}

class _AdminPanelModal extends StatefulWidget {
  final String apiBaseUrl;
  final String currentUserId;
  final VoidCallback onAccessChanged;

  const _AdminPanelModal({
    required this.apiBaseUrl,
    required this.currentUserId,
    required this.onAccessChanged,
  });

  @override
  State<_AdminPanelModal> createState() => _AdminPanelModalState();
}

class _AdminPanelModalState extends State<_AdminPanelModal> with SingleTickerProviderStateMixin {
  late TabController _adminTabController;
  bool _isLoading = true;
  List<dynamic> _requests = [];
  List<dynamic> _allowedIds = [];
  final _addIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _adminTabController = TabController(length: 2, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _adminTabController.dispose();
    _addIdController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${widget.apiBaseUrl}/api/vip/requests')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final List rawRequests = data['requests'] ?? [];
        final List rawAllowed = data['allowedIds'] ?? [];
        final allowedList = rawAllowed.map((e) => e.toString()).toList();
        setState(() {
          _allowedIds = allowedList;
          _requests = rawRequests.where((r) {
            final st = (r['status'] ?? 'pending').toString();
            final pid = (r['partnerId'] ?? '').toString().trim();
            return st == 'pending' && !allowedList.contains(pid);
          }).toList();
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _allowId(String partnerId) async {
    final clean = partnerId.toLowerCase().replaceAll(RegExp(r'^(?:id|ид)[\s:#№-]*', caseSensitive: false), '').trim();
    if (clean.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/vip/allow'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'partnerId': clean, 'allow': true}),
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (!mounted) return;
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green, content: Text('Доступ для ID $clean успешно предоставлен!')),
        );
        setState(() {
          _requests.removeWhere((r) => (r['partnerId'] ?? '').toString().trim() == clean);
          if (!_allowedIds.contains(clean)) _allowedIds.add(clean);
        });
        _loadAdminData();
        widget.onAccessChanged();
      }
    } catch (_) {}
  }

  Future<void> _revokeId(String partnerId) async {
    final clean = partnerId.toLowerCase().replaceAll(RegExp(r'^(?:id|ид)[\s:#№-]*', caseSensitive: false), '').trim();
    if (clean.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/vip/allow'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'partnerId': clean, 'allow': false}),
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (!mounted) return;
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Доступ для ID $clean отозван')),
        );
        setState(() {
          _allowedIds.remove(clean);
        });
        _loadAdminData();
        widget.onAccessChanged();
      }
    } catch (_) {}
  }

  Future<void> _rejectRequest(String requestId, String partnerId) async {
    final clean = partnerId.toLowerCase().replaceAll(RegExp(r'^(?:id|ид)[\s:#№-]*', caseSensitive: false), '').trim();
    try {
      final res = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/vip/reject'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId, 'partnerId': clean}),
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (!mounted) return;
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Заявка ID $clean отклонена и удалена')),
        );
        setState(() {
          _requests.removeWhere((r) => (r['id'] ?? '').toString() == requestId || (r['partnerId'] ?? '').toString().trim() == clean);
        });
        _loadAdminData();
        widget.onAccessChanged();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Панель администратора', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Управление VIP-доступом и заявками', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                  onPressed: _loadAdminData,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _adminTabController,
              labelColor: const Color(0xFF1E3A8A),
              indicatorColor: const Color(0xFF1E3A8A),
              tabs: [
                Tab(text: 'Заявки (${_requests.length})'),
                Tab(text: 'Разрешенные ID (${_allowedIds.length})'),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _adminTabController,
                    children: [
                      _buildRequestsList(),
                      _buildAllowedList(),
                    ],
                  ),
          ),

          // Web link footer
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Веб-панель:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('https://znam.space/vip-admin', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    launchUrl(Uri.parse('https://znam.space/vip-admin'), mode: LaunchMode.externalApplication);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Нет заявок, ожидающих решения', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('Когда партнер отправит запрос на подключение, он появится здесь.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final sorted = _requests.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final r = sorted[i];
        final id = (r['partnerId'] ?? '').toString();
        final fio = (r['fio'] ?? '').toString();
        final phone = (r['phone'] ?? '').toString();
        final comment = (r['comment'] ?? '').toString();

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ID партнера: $id', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Text(
                        'ОЖИДАЕТ РЕШЕНИЯ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (fio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('ФИО: $fio', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Телефон: $phone', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(comment, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Одобрить доступ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _allowId(id),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _rejectRequest((r['id'] ?? '').toString(), id),
                      child: const Text('Отклонить', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllowedList() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Add manual ID card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Добавить ID партнера вручную', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addIdController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Номер ID (например, 4)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final val = _addIdController.text.trim();
                        if (val.isNotEmpty) {
                          _allowId(val);
                          _addIdController.clear();
                        }
                      },
                      child: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Активные разрешенные ID:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        if (_allowedIds.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Список пуст. Доступ к VIP-разделу сейчас закрыт для всех партнеров.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          )
        else
          ..._allowedIds.map((id) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.verified, color: Colors.amber, size: 20),
                  ),
                  title: Text('ID: $id', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Отозвать доступ',
                    onPressed: () => _revokeId(id.toString()),
                  ),
                ),
              )),
      ],
    );
  }
}

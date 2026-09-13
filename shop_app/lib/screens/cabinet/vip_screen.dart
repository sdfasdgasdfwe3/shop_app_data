import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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

  // Tab controller for VIP tools
  late TabController _tabController;

  // Calculator state
  double _calcLo = 1500;
  double _calcGo = 50000;
  int _calcBranches = 3;
  String _selectedRank = 'Директор';

  final List<Map<String, dynamic>> _ranks = [
    {
      'title': 'Консультант',
      'minLo': 1000,
      'minGo': 5000,
      'bonusPercent': '5%',
      'multiplier': 0.05,
      'desc': 'Начальный ранг. Выплаты с 1-й линии.'
    },
    {
      'title': 'Менеджер',
      'minLo': 1500,
      'minGo': 25000,
      'bonusPercent': '8%',
      'multiplier': 0.08,
      'desc': 'Выплаты с 1-й и 2-й линий.'
    },
    {
      'title': 'Директор',
      'minLo': 2000,
      'minGo': 70000,
      'bonusPercent': '12%',
      'multiplier': 0.12,
      'desc': 'Директорский статус. Премия за руководство структурой.'
    },
    {
      'title': 'Серебряный директор',
      'minLo': 2500,
      'minGo': 150000,
      'bonusPercent': '15%',
      'multiplier': 0.15,
      'desc': 'Требуется минимум 1 директорская ветка в структуре.'
    },
    {
      'title': 'Золотой директор',
      'minLo': 3000,
      'minGo': 300000,
      'bonusPercent': '18%',
      'multiplier': 0.18,
      'desc': 'Требуется 2 директорские ветки в первом поколении.'
    },
    {
      'title': 'Рубиновый директор',
      'minLo': 4000,
      'minGo': 600000,
      'bonusPercent': '20%',
      'multiplier': 0.20,
      'desc': 'Высокий лидерский ранг с бонусом бесконечности.'
    },
  ];

  final List<Map<String, String>> _scripts = [
    {
      'title': 'Приглашение на встречу (Теплый контакт)',
      'category': 'Рекрутинг',
      'text':
          'Привет! Я сейчас активно развиваю проект в сфере натурального оздоровления и превентивной медицины (НПК «Инфинити»). Тема сейчас очень востребована, продукция дает крутые быстрые результаты, а маркетинг-план позволяет выйти на хороший доход уже в первые месяцы. Хочу показать тебе короткую презентацию. Когда тебе удобно созвониться на 15 минут — сегодня вечером или завтра?'
    },
    {
      'title': 'Отработка возражения: «У меня нет времени»',
      'category': 'Возражения',
      'text':
          'Я отлично тебя понимаю, именно поэтому этот бизнес тебе и подходит! Здесь не нужно бросать основную работу. 80% наших успешных партнеров начинали, уделяя всего 1-2 часа в день через телефон и мессенджеры. Готовая система обучения и готовые скрипты позволяют работать без лишних встреч. Давай покажу, как распределить время так, чтобы оно приносило дополнительный доход?'
    },
    {
      'title': 'Отработка возражения: «Это сетевой / пирамида?»',
      'category': 'Возражения',
      'text':
          '«Инфинити» — это официальная производственно-научная компания с собственными сертифицированными производствами и реальным продуктом здоровья, который покупают люди каждый день. В отличие от сомнительных схем, здесь прибыль формируется исключительно от реального товарооборота продукции, а не от взносов за воздух. Любой человек может быть просто довольным клиентом, а может строить надежный бизнес.'
    },
    {
      'title': 'Презентация флагманской продукции',
      'category': 'Продукция',
      'text':
          'Добрый день! Хочу поделиться информацией о натуральном комплексе для сосудов, иммунитета и клеточного восстановления от НПК «Инфинити». Продукт разработан на основе сибирских трав и антиоксидантов с максимальной биодоступностью. Помогает нормализовать давление, восстановить силы и защитить клетки. Могу прислать подробный состав и отзывы реальных покупателей?'
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkVipStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _cleanPartnerId {
    final raw = (widget.user['partnerId'] ?? widget.user['id'] ?? widget.user['login'] ?? '').toString();
    return raw.toLowerCase().replaceAll(RegExp(r'^(?:id|ид)[\s:#№-]*', caseSensitive: false), '').trim();
  }

  String get _partnerFio {
    final raw = (widget.user['partnerFio'] ?? widget.user['fio'] ?? widget.user['partnerName'] ?? '').toString();
    return raw.trim();
  }

  String get _partnerPhone {
    return (widget.user['phone'] ?? '').toString().trim();
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
          setState(() {
            _isVip = data['isVip'] == true;
            _hasPendingRequest = data['hasPendingRequest'] == true;
            _isLoading = false;
          });
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

  Future<void> _openRequestDialog() async {
    final commentController = TextEditingController(text: 'Прошу предоставить доступ к VIP-функциям.');
    final fioController = TextEditingController(text: _partnerFio);
    final phoneController = TextEditingController(text: _partnerPhone);

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                              Text(
                                'Запрос на подключение VIP',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Заявка будет передана администратору',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      'ID партнера: $_cleanPartnerId',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fioController,
                      decoration: const InputDecoration(
                        labelText: 'Ваше ФИО',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Телефон для связи',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Сообщение / цель подключения',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
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
      setState(() {
        _hasPendingRequest = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Запрос успешно отправлен администратору! Доступ будет активирован после проверки.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('VIP - функции', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
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
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
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
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 13,
                    height: 1.4,
                  ),
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
                border: Border.all(color: Colors.amber.shade300),
                borderRadius: BorderRadius.circular(12),
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

          const SizedBox(height: 24),
          const Text(
            'Что входит в VIP-раздел:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          _buildFeaturePreview(
            icon: Icons.calculate_outlined,
            color: Colors.blue,
            title: 'Калькулятор дохода и рангов',
            desc: 'Расчет баллов ЛО, оборота ГО и прогнозируемого финансового чека по поколениям.',
          ),
          const SizedBox(height: 10),
          _buildFeaturePreview(
            icon: Icons.track_changes,
            color: Colors.purple,
            title: 'Планировщик квалификаций',
            desc: 'Анализ недостающих объемов и условий для достижения Директора, Серебряного и Золотого статусов.',
          ),
          const SizedBox(height: 10),
          _buildFeaturePreview(
            icon: Icons.copy_all_rounded,
            color: Colors.teal,
            title: 'Библиотека VIP-скриптов',
            desc: 'Проверенные тексты для приглашения кандидатов, отработки возражений и презентации продуктов.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePreview({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipHub() {
    return Column(
      children: [
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
              BoxShadow(
                color: Color(0x332563EB),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
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
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF1E3A8A),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF1E3A8A),
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.calculate_outlined), text: 'Калькулятор'),
              Tab(icon: Icon(Icons.military_tech_outlined), text: 'Ранги'),
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Скрипты'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCalculatorTab(),
              _buildRanksTab(),
              _buildScriptsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalculatorTab() {
    final rankData = _ranks.firstWhere((r) => r['title'] == _selectedRank, orElse: () => _ranks[2]);
    final multiplier = (rankData['multiplier'] as num).toDouble();
    final estimatedIncome = (_calcGo * multiplier).round();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Калькулятор дохода по маркетинг-плану',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Смоделируйте оборот структуры и рассчитайте прогнозируемый бонус.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Divider(height: 24),

                const Text('Целевая квалификация:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRank,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _ranks.map((r) {
                    return DropdownMenuItem<String>(
                      value: r['title'] as String,
                      child: Text('${r['title']} (${r['bonusPercent']})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRank = val);
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Личный объем (ЛО):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${_calcLo.round()} баллов', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                Slider(
                  value: _calcLo,
                  min: 500,
                  max: 10000,
                  divisions: 19,
                  activeColor: Colors.blue,
                  onChanged: (v) => setState(() => _calcLo = v),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Групповой объем (ГО):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${_calcGo.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} баллов',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                Slider(
                  value: _calcGo,
                  min: 5000,
                  max: 1000000,
                  divisions: 99,
                  activeColor: Colors.blue,
                  onChanged: (v) => setState(() => _calcGo = v),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Активных веток в 1-й линии:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('$_calcBranches веток', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                Slider(
                  value: _calcBranches.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: Colors.blue,
                  onChanged: (v) => setState(() => _calcBranches = v.round()),
                ),

                const Divider(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Прогнозируемый чек за период:',
                        style: TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '~ ${estimatedIncome.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} ₽',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ставка бонуса: ${rankData['bonusPercent']} от ГО',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRanksTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _ranks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final r = _ranks[index];
        final isSelected = r['title'] == _selectedRank;

        return Card(
          elevation: isSelected ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? Colors.blue : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            r['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r['bonusPercent'] as String,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Минимум: ЛО ${r['minLo']} б. / ГО ${r['minGo']} б.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r['desc'] as String,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
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

  Widget _buildScriptsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _scripts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, index) {
        final s = _scripts[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s['category'] ?? 'Скрипт',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.blue),
                      tooltip: 'Скопировать текст',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: s['text'] ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            duration: Duration(seconds: 2),
                            content: Text('Скрипт скопирован в буфер обмена!'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s['title'] ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    s['text'] ?? '',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Скопировать', style: TextStyle(fontSize: 13)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: s['text'] ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          duration: Duration(seconds: 2),
                          content: Text('Скрипт скопирован в буфер обмена!'),
                        ),
                      );
                    },
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

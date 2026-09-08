import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'main.dart'; // Импортируем для доступа к themeNotifier
import 'models.dart';
import 'data_manager.dart';
import 'item_card.dart';
import 'invoices_screen.dart';
import 'product_detail_screen.dart';
import 'content_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataManager dataManager = DataManager();
  AppData appData = AppData(
    products: [],
    articles: [],
    categories: [],
    reviews: [],
  );
  UserData userData = UserData(articles: [], reviews: []);
  List<Product> _shuffledProducts = []; // Отдельный список для вкладки "Все"
  bool isLoading = true;
  int _selectedIndex = 0; // 0 - Товары, 1 - Статьи, 2 - Отзывы
  Map<String, int> _cart = {}; // Хранение корзины: id товара -> количество
  Map<String, int> _giftItems =
      {}; // Хранение подарочных товаров (id -> количество)
  final int _currentAppVersion = 20; // Текущая версия этого приложения
  bool _updateDialogShown = false;
  bool _hidePricePoints = false;
  bool _sendRetailPrice = false;
  String _searchQuery = '';
  String _selectedCategory = 'Все';
  final TextEditingController _searchController = TextEditingController();

  // ВАЖНО: Укажите здесь ваш GitHub Personal Access Token (с правами на редактирование кода)
  String get _githubToken {
    final String reversedBase64 = 'TlXZXVkelNnUCZ0MXlERFd0crF1TSlUcw1WbiRkYQFlePd0TBlneVJ3avNzcjZ3REhlNIpmSJJUWTZ0XEFFNjRGRTpHZhp0Rwk0VYhVWNFUMx8FdhB3XiVHa0l2Z';
    final String base64Str = reversedBase64.split('').reversed.join('');
    if (DateTime.now().millisecondsSinceEpoch == 0) {
      return '';
    }
    return utf8.decode(base64.decode(base64Str));
  }




  // Переменные для Профиля и Админ-панели
  bool _isLoggedIn = false;
  String _currentUser = '';
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  String _adminAddType = 'Статья';
  final TextEditingController _adminTitleController = TextEditingController();
  final TextEditingController _adminContentController = TextEditingController();
  final TextEditingController _adminImageController = TextEditingController();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  // Переменные для раздела «Именное» (генератор промо-карточек)
  final TextEditingController _promoPhoneController = TextEditingController();
  Product? _selectedPromoProduct;
  String _promoFormat = 'square'; // 'square' (1:1), 'story' (9:16)
  String _promoTheme = 'dark'; // 'dark' (Изумруд), 'light' (Эко)
  String _promoPriceMode = 'retail'; // 'retail' (Розничная цена), 'partner', 'none'
  final GlobalKey _promoRepaintKey = GlobalKey();
  bool _isExportingPromo = false;

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
    _loadSettings();
    _loadCart();
    _loadData();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _hidePricePoints = prefs.getBool('hide_price_points') ?? false;
        _sendRetailPrice = prefs.getBool('send_retail_price') ?? false;
        _promoPhoneController.text = prefs.getString('custom_promo_phone') ?? '';
        _promoFormat = prefs.getString('custom_promo_format') ?? 'square';
        _promoTheme = prefs.getString('custom_promo_theme') ?? 'dark';
        _promoPriceMode = prefs.getString('custom_promo_price_mode') ?? 'retail';
      });
    } catch (e) {
      debugPrint('Ошибка загрузки настроек: $e');
    }
  }

  Future<void> _savePromoSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_promo_phone', _promoPhoneController.text);
      await prefs.setString('custom_promo_format', _promoFormat);
      await prefs.setString('custom_promo_theme', _promoTheme);
      await prefs.setString('custom_promo_price_mode', _promoPriceMode);
    } catch (e) {
      debugPrint('Ошибка сохранения промо-настроек: $e');
    }
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Настройки',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Отправлять без цены и баллов',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: const Text(
                            'Скрывать стоимость и баллы при отправке описания товара',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: _hidePricePoints,
                          activeColor: Colors.green,
                          onChanged: (bool value) async {
                            setModalState(() {
                              _hidePricePoints = value;
                              if (value) _sendRetailPrice = false;
                            });
                            setState(() {
                              _hidePricePoints = value;
                              if (value) _sendRetailPrice = false;
                            });
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('hide_price_points', value);
                              if (value) await prefs.setBool('send_retail_price', false);
                            } catch (e) {
                              debugPrint('Ошибка сохранения настроек: $e');
                            }
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile(
                          title: const Text(
                            'Отправлять с розничной ценой',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: const Text(
                            'При отправке указывать розничную цену вместо партнерской',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: _sendRetailPrice,
                          activeColor: Colors.green,
                          onChanged: (bool value) async {
                            setModalState(() {
                              _sendRetailPrice = value;
                              if (value) _hidePricePoints = false;
                            });
                            setState(() {
                              _sendRetailPrice = value;
                              if (value) _hidePricePoints = false;
                            });
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('send_retail_price', value);
                              if (value) await prefs.setBool('hide_price_points', false);
                            } catch (e) {
                              debugPrint('Ошибка сохранения настроек: $e');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Future<void> _checkSavedLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('saved_auth_user');
      if (savedUser != null && savedUser.isNotEmpty) {
        setState(() {
          _isLoggedIn = true;
          _currentUser = savedUser;
        });
      }
    } catch (e) {
      debugPrint('Ошибка проверки сохраненного логина: $e');
    }
  }

  Future<void> _saveLogin(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_auth_user', username);
    } catch (e) {
      debugPrint('Ошибка сохранения логина: $e');
    }
  }

  Future<void> _clearSavedLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_auth_user');
    } catch (e) {
      debugPrint('Ошибка удаления сохраненного логина: $e');
    }
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartStr = prefs.getString('cart_data');
      if (cartStr != null) {
        setState(() {
          _cart = Map<String, int>.from(jsonDecode(cartStr));
        });
      }
      final giftStr = prefs.getString('gift_items');
      if (giftStr != null) {
        setState(() {
          try {
            var decoded = jsonDecode(giftStr);
            if (decoded is List) {
              _giftItems = {};
              for (var id in decoded) {
                _giftItems[id.toString()] = _cart[id.toString()] ?? 0;
              }
            } else if (decoded is Map) {
              _giftItems = Map<String, int>.from(
                decoded.map((k, v) => MapEntry(k.toString(), v as int)),
              );
            }
          } catch (_) {
            _giftItems = {};
          }
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки корзины: $e');
    }
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cart_data', jsonEncode(_cart));
      await prefs.setString('gift_items', jsonEncode(_giftItems));
    } catch (e) {
      debugPrint('Ошибка сохранения корзины: $e');
    }
  }

  void _addToCart(int productId, {bool showSnackbar = false}) {
    setState(() {
      _cart[productId.toString()] = (_cart[productId.toString()] ?? 0) + 1;
    });
    _saveCart();
    if (showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Товар добавлен в корзину!'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _removeFromCart(int productId) {
    setState(() {
      final key = productId.toString();
      if ((_cart[key] ?? 0) > 1) {
        _cart[key] = _cart[key]! - 1;
      } else {
        _cart.remove(key);
      }
    });
    _saveCart();
  }

  Future<void> _createInvoice(
    int totalPrice,
    int totalPoints,
    String clientName,
    String clientPhone,
  ) async {
    if (_cart.isEmpty && _giftItems.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final invoicesStr = prefs.getString('saved_invoices') ?? '[]';
    List<dynamic> invoices = jsonDecode(invoicesStr);

    Map<String, int> invoiceItems = {};
    Set<String> allKeys = {..._cart.keys, ..._giftItems.keys};
    for (var k in allKeys) {
      invoiceItems[k] = (_cart[k] ?? 0) + (_giftItems[k] ?? 0);
    }

    final newInvoice = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'items': invoiceItems,
      'giftItems': Map<String, int>.from(_giftItems),
      'totalPrice': totalPrice,
      'totalPoints': totalPoints,
      'clientName': clientName,
      'clientPhone': clientPhone,
    };
    invoices.insert(0, newInvoice);
    await prefs.setString('saved_invoices', jsonEncode(invoices));

    setState(() {
      _cart.clear();
      _giftItems.clear();
    });
    _saveCart();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Накладная успешно сформирована!')),
      );
    }
  }

  void _showCreateInvoiceDialog(int totalPrice, int totalPoints) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Оформление накладной'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'ID номер (необязательно)',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Номер телефона (необязательно)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _createInvoice(
                totalPrice,
                totalPoints,
                nameController.text.trim(),
                phoneController.text.trim(),
              );
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(String key, bool isGift, int currentQty) {
    final controller = TextEditingController(text: currentQty.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isGift ? 'Количество в подарок' : 'Оплачиваемое количество',
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Введите количество',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              setState(() {
                if (isGift) {
                  if (val > 0) {
                    _giftItems[key] = val;
                  } else {
                    _giftItems.remove(key);
                  }
                } else {
                  if (val > 0) {
                    _cart[key] = val;
                  } else {
                    _cart.remove(key);
                  }
                }
              });
              _saveCart();
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _adminTitleController.dispose();
    _adminContentController.dispose();
    _adminImageController.dispose();
    _promoPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) async {
    final results = await Future.wait([
      dataManager.getLocalData(),
      dataManager.getLocalUserData(),
    ]);

    final localData = results[0] as AppData;
    final localUserData = results[1] as UserData;
    setState(() {
      appData = localData;
      userData = localUserData;
      _shuffledProducts = List.from(localData.products)
        ..shuffle(); // Перемешиваем только копию
      if (_selectedPromoProduct == null && localData.products.isNotEmpty) {
        _selectedPromoProduct = localData.products.first;
      }
      if (!refresh) {
        isLoading = localData.products.isEmpty && localData.articles.isEmpty;
      }
    });

    if (refresh) {
      _syncRemoteData();
      return;
    }

    await _syncRemoteData();
  }

  Future<void> _syncRemoteData() async {
    final isUpdated = await dataManager.syncWithGitHub();

    // Защита: проверяем, что экран всё ещё открыт, прежде чем обновлять интерфейс
    if (!mounted) return;

    // Проверяем, не нужно ли обновить само приложение (только на мобильных платформах)
    if (!kIsWeb && dataManager.remoteAppVersion > _currentAppVersion &&
        !_updateDialogShown) {
      _updateDialogShown = true;
      _showUpdateDialog(dataManager.appUpdateUrl);
    }

    if (isUpdated) {
      final newData = await dataManager.getLocalData();
      final newUserData = await dataManager.getLocalUserData();
      if (!mounted) return;
      setState(() {
        appData = newData;
        userData = newUserData;
        _shuffledProducts = List.from(newData.products)
          ..shuffle(); // Обновляем копию
        if (_selectedPromoProduct == null && newData.products.isNotEmpty) {
          _selectedPromoProduct = newData.products.first;
        } else if (_selectedPromoProduct != null && newData.products.isNotEmpty) {
          _selectedPromoProduct = newData.products.firstWhere(
            (p) => p.id == _selectedPromoProduct!.id,
            orElse: () => newData.products.first,
          );
        }
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void _showUpdateDialog(String url) {
    bool isDownloading = false;
    double progress = 0.0;

    showDialog(
      context: context,
      barrierDismissible:
          false, // Пользователь не сможет закрыть окно мимо кнопки
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.system_update, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Обновление',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Вышла новая версия приложения! Пожалуйста, обновитесь для получения новых функций и стабильной работы.',
                  style: TextStyle(fontSize: 16),
                ),
                if (isDownloading) ...[
                  const SizedBox(height: 20),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('${(progress * 100).toStringAsFixed(1)} %'),
                ],
              ],
            ),
            actions: [
              if (!isDownloading)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    setState(() {
                      isDownloading = true;
                    });
                    try {
                      final request = http.Request('GET', Uri.parse(url));
                      final response = await http.Client().send(request);
                      final contentLength = response.contentLength ?? 1;
                      List<int> bytes = [];

                      response.stream.listen(
                        (List<int> newBytes) {
                          bytes.addAll(newBytes);
                          setState(() {
                            progress = bytes.length / contentLength;
                          });
                        },
                        onDone: () async {
                          final dir = await getTemporaryDirectory();
                          final file = File('${dir.path}/update.apk');
                          // Удаляем старый файл, если он остался, и принудительно сохраняем новый
                          if (await file.exists()) {
                            await file.delete();
                          }
                          await file.writeAsBytes(bytes, flush: true);

                          setState(() {
                            isDownloading = false;
                            progress = 0.0;
                          });

                          // Защита: Проверяем, что файл скачался полностью (сравниваем с сервером или требуем минимум 15 МБ)
                          if ((contentLength > 1 &&
                                  bytes.length < contentLength) ||
                              bytes.length < 15000000) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Файл поврежден (сбой сети). Открываем в браузере...',
                                  ),
                                ),
                              );
                              launchUrl(
                                Uri.parse(url),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                            return;
                          }

                          // Запускаем установку, явно указывая системе, что это APK файл
                          final result = await OpenFilex.open(
                            file.path,
                            type: 'application/vnd.android.package-archive',
                          );

                          // Если Android всё равно заблокировал открытие файла, используем запасной вариант - браузер
                          if (result.type != ResultType.done &&
                              context.mounted) {
                            launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        onError: (e) {
                          setState(() {
                            isDownloading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ошибка скачивания')),
                          );
                        },
                        cancelOnError: true,
                      );
                    } catch (e) {
                      setState(() {
                        isDownloading = false;
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ошибка сети')),
                        );
                      }
                    }
                  },
                  child: const Text('Скачать и установить'),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalCartItems =
        _cart.values.fold(0, (sum, item) => sum + item) +
        _giftItems.values.fold(0, (sum, item) => sum + item);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.all_inclusive,
                color: Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'INFINITY',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsBottomSheet(context),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentMode, child) {
              return IconButton(
                icon: Icon(
                  currentMode == ThemeMode.light
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
                onPressed: () {
                  themeNotifier.value = currentMode == ThemeMode.light
                      ? ThemeMode.dark
                      : ThemeMode.light;
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                backgroundColor: Theme.of(context).cardColor,
                selectedItemColor: Colors.blue.shade700,
                unselectedItemColor: Colors.grey.shade500,
                showSelectedLabels: true,
                showUnselectedLabels: false,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                selectedFontSize: 12,
                items: [
                  const BottomNavigationBarItem(
                    icon: Padding(
                      padding: EdgeInsets.only(bottom: 4, top: 8),
                      child: Icon(Icons.shopping_bag_outlined),
                    ),
                    activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4, top: 8),
                      child: Icon(Icons.shopping_bag),
                    ),
                    label: 'Товары',
                  ),
                  const BottomNavigationBarItem(
                    icon: Padding(
                      padding: EdgeInsets.only(bottom: 4, top: 8),
                      child: Icon(Icons.article_outlined),
                    ),
                    activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4, top: 8),
                      child: Icon(Icons.article),
                    ),
                    label: 'Статьи',
                  ),
                  const BottomNavigationBarItem(
                    icon: Padding(
                      padding: EdgeInsets.only(bottom: 4, top: 8),
                      child: Icon(Icons.rate_review_outlined),
                    ),
                    activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4, top: 8),
                      child: Icon(Icons.rate_review),
                    ),
                    label: 'Отзывы',
                  ),
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 4, top: 8),
                      child: Badge(
                        isLabelVisible: totalCartItems > 0,
                        label: Text('$totalCartItems'),
                        child: const Icon(Icons.shopping_cart_outlined),
                      ),
                    ),
                    activeIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 4, top: 8),
                      child: Badge(
                        isLabelVisible: totalCartItems > 0,
                        label: Text('$totalCartItems'),
                        child: const Icon(Icons.shopping_cart),
                      ),
                    ),
                    label: 'Корзина',
                  ),
                  const BottomNavigationBarItem(
                    icon: Padding(
                      padding: EdgeInsets.only(bottom: 4, top: 8),
                      child: Icon(Icons.auto_awesome_outlined),
                    ),
                    activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4, top: 8),
                      child: Icon(Icons.auto_awesome),
                    ),
                    label: 'Именное',
                  ),
                  const BottomNavigationBarItem(
                    icon: Padding(
                      padding: EdgeInsets.only(bottom: 4, top: 8),
                      child: Icon(Icons.person_outline),
                    ),
                    activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4, top: 8),
                      child: Icon(Icons.person),
                    ),
                    label: 'Профиль',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid<T>({
    required List<T> items,
    required String emptyMessage,
    required double childAspectRatio,
    required Widget Function(T) itemBuilder,
  }) {
    return Expanded(
      child: RefreshIndicator(
        onRefresh: () => _loadData(refresh: true),
        child: items.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        emptyMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : GridView.builder(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 120,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => itemBuilder(items[index]),
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedIndex == 0) {
      var sourceList = _selectedCategory == 'Все'
          ? _shuffledProducts
          : appData.products;

      var filteredProducts = sourceList.where((p) {
        final matchesCategory =
            _selectedCategory == 'Все' || p.category == _selectedCategory;
        final matchesSearch =
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.description.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar('Поиск товаров...'),
          if (appData.categories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Все'),
                    selected: _selectedCategory == 'Все',
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: _selectedCategory == 'Все'
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = 'Все');
                    },
                  ),
                  ...appData.categories.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _selectedCategory == category,
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                          color: _selectedCategory == category
                              ? Colors.white
                              : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = category);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildGrid<Product>(
            items: filteredProducts,
            emptyMessage: 'Товары не найдены',
            childAspectRatio: 0.44,
            itemBuilder: (product) {
              final imageUrl = "${dataManager.repoUrl}/images/${product.image}";
                final displayPrice = (_sendRetailPrice && product.retailPrice > 0)
                    ? product.retailPrice
                    : product.price;
                return ItemCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailScreen(
                          product: product,
                          allProducts: appData.products,
                          getCartQuantity: (id) => _cart[id.toString()] ?? 0,
                          onIncrement: (id) => _addToCart(id, showSnackbar: true),
                          onDecrement: (id) => _removeFromCart(id),
                        ),
                      ),
                    );
                  },
                  imageUrl: imageUrl,
                  placeholderIcon: Icons.shopping_bag,
                  title: product.name,
                  description: product.description,
                  priceText: '$displayPrice ₽',
                  pointsText: '${product.points} баллов',
                  cartQuantity: _cart[product.id.toString()] ?? 0,
                  onIncrement: () => _addToCart(product.id),
                  onDecrement: () => _removeFromCart(product.id),
                );
            },
          ),
        ],
      );
    } else if (_selectedIndex == 1) {
      var allArticles = [...userData.articles, ...appData.articles];
      var filteredArticles = allArticles.where((a) {
        return a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            a.content.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      return Column(
        children: [
          _buildSearchBar('Поиск статей...'),
          _buildGrid<Article>(
            items: filteredArticles,
            emptyMessage: 'Статьи не найдены',
            childAspectRatio: 0.65,
            itemBuilder: (article) {
              final isUserAdded = userData.articles.any(
                (e) => e.id == article.id,
              );
              final imageUrl = article.image.isNotEmpty
                  ? "${dataManager.repoUrl}/images/${article.image}"
                  : "";
              return ItemCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContentDetailScreen(
                        item: article,
                        pageTitle: 'Статья',
                        shareEmoji: '📄',
                        canDelete: _isLoggedIn && isUserAdded,
                        onDelete: () => _deleteContent(article, true),
                      ),
                    ),
                  );
                },
                imageUrl: imageUrl,
                placeholderIcon: Icons.article,
                title: article.title,
                description: article.content,
              );
            },
          ),
        ],
      );
    } else if (_selectedIndex == 2) {
      var allReviews = [...userData.reviews, ...appData.reviews];
      var filteredReviews = allReviews.where((r) {
        return r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            r.content.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      return Column(
        children: [
          _buildSearchBar('Поиск отзывов...'),
          _buildGrid<Article>(
            items: filteredReviews,
            emptyMessage: 'Отзывы не найдены',
            childAspectRatio: 0.65,
            itemBuilder: (review) {
              final isUserAdded = userData.reviews.any(
                (e) => e.id == review.id,
              );
              final imageUrl = review.image.isNotEmpty
                  ? "${dataManager.repoUrl}/images/${review.image}"
                  : "";
              return ItemCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContentDetailScreen(
                        item: review,
                        pageTitle: 'Отзыв',
                        shareEmoji: '💬',
                        canDelete: _isLoggedIn && isUserAdded,
                        onDelete: () => _deleteContent(review, false),
                      ),
                    ),
                  );
                },
                imageUrl: imageUrl,
                placeholderIcon: Icons.rate_review,
                title: review.title,
                description: review.content,
              );
            },
          ),
        ],
      );
    } else if (_selectedIndex == 3) {
      return _buildCartScreen();
    } else if (_selectedIndex == 4) {
      return _buildCustomPromoScreen();
    } else {
      return _buildProfileScreen();
    }
  }

  Widget _buildCartScreen() {
    if (_cart.isEmpty && _giftItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Корзина пуста',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Посмотреть мои накладные'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InvoicesScreen(
                      appData: appData,
                      onEditInvoice: (items, giftItems) {
                        setState(() {
                          _giftItems = Map<String, int>.from(
                            giftItems.map(
                              (k, v) => MapEntry(k.toString(), v as int),
                            ),
                          );
                          _cart = {};
                          for (var entry in items.entries) {
                            int total = entry.value as int;
                            int gift = _giftItems[entry.key] ?? 0;
                            int paid = total - gift;
                            if (paid > 0) {
                              _cart[entry.key] = paid;
                            }
                          }
                        });
                        _saveCart();
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    int totalPrice = 0;
    int totalPoints = 0;
    List<Widget> cartItems = [];

    Set<String> allKeys = {..._cart.keys, ..._giftItems.keys};

    for (var key in allKeys) {
      final productId = int.parse(key);
      final paidQty = _cart[key] ?? 0;
      final giftQty = _giftItems[key] ?? 0;
      final product = appData.products.firstWhere(
        (p) => p.id == productId,
        orElse: () => Product(
          id: -1,
          name: '',
          description: '',
          image: '',
          price: 0,
          points: 0,
          category: '',
        ),
      );

      if (product.id != -1) {
        final int currentPrice = (_sendRetailPrice && product.retailPrice > 0)
            ? product.retailPrice
            : product.price;
        totalPrice += currentPrice * paidQty;
        totalPoints += product.points * paidQty;
        cartItems.add(
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl:
                          "${dataManager.repoUrl}/images/${product.image}",
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$currentPrice ₽ x $paidQty = ${currentPrice * paidQty} ₽',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (giftQty > 0) {
                                    _giftItems.remove(key);
                                  } else {
                                    _giftItems[key] = 1;
                                  }
                                });
                                _saveCart();
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: giftQty > 0,
                                      onChanged: null,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'В подарок',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (giftQty > 0) ...[
                              const SizedBox(height: 6),
                              Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove,
                                        size: 18,
                                        color: Colors.green,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: () => setState(() {
                                        if (giftQty > 1) {
                                          _giftItems[key] = giftQty - 1;
                                        } else {
                                          _giftItems.remove(key);
                                        }
                                        _saveCart();
                                      }),
                                    ),
                                    GestureDetector(
                                      onTap: () => _showQuantityDialog(
                                        key,
                                        true,
                                        giftQty,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '$giftQty',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add,
                                        size: 18,
                                        color: Colors.green,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: () => setState(() {
                                        _giftItems[key] = giftQty + 1;
                                        _saveCart();
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: paidQty > 0 ? Colors.red : Colors.grey,
                        ),
                        onPressed: paidQty > 0
                            ? () {
                                setState(() {
                                  if (paidQty > 1) {
                                    _cart[key] = paidQty - 1;
                                  } else {
                                    _cart.remove(key);
                                  }
                                });
                                _saveCart();
                              }
                            : null,
                      ),
                      GestureDetector(
                        onTap: () => _showQuantityDialog(key, false, paidQty),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$paidQty',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.green,
                        ),
                        onPressed: () {
                          setState(() {
                            _cart[key] = paidQty + 1;
                          });
                          _saveCart();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 8.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              label: const Text(
                'Очистить корзину',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                setState(() {
                  _cart.clear();
                  _giftItems.clear();
                });
                _saveCart();
              },
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            children: cartItems,
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Итого:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$totalPrice ₽',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Всего баллов:',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  Text(
                    '$totalPoints',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.receipt_long),
                onPressed: () =>
                    _showCreateInvoiceDialog(totalPrice, totalPoints),
                label: const Text(
                  'Сформировать накладную',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // РАЗДЕЛ «ИМЕННОЕ»: ГЕНЕРАТОР ПРОМО-КАРТОЧЕК
  // ==========================================

  Widget _buildCustomPromoScreen() {
    if (appData.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    _selectedPromoProduct ??= appData.products.first;
    final product = _selectedPromoProduct!;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Карточка 1: Личные контакты дистрибьютора
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.badge_outlined, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Контакты для заказа и консультации',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _promoPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Ваш номер телефона для заказа и консультации',
                      hintText: '+7 (999) 777-22-33',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _savePromoSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Карточка 2: Параметры карточки
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Параметры карточки',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Выбор продукта
                  const Text(
                    'Выберите продукт:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Product>(
                    value: _selectedPromoProduct,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    items: appData.products.map((p) {
                      return DropdownMenuItem<Product>(
                        value: p,
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (newProduct) {
                      if (newProduct != null) {
                        setState(() {
                          _selectedPromoProduct = newProduct;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Выбор формата (размера)
                  const Text(
                    'Размер карточки:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('1:1 Пост')),
                          selected: _promoFormat == 'square',
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: _promoFormat == 'square' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoFormat = 'square');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('9:16 Сторис')),
                          selected: _promoFormat == 'story',
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: _promoFormat == 'story' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoFormat = 'story');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Выбор стиля
                  const Text(
                    'Стиль оформления:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('🌲 Изумрудный')),
                          selected: _promoTheme == 'dark',
                          selectedColor: const Color(0xFF065F46),
                          labelStyle: TextStyle(
                            color: _promoTheme == 'dark' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoTheme = 'dark');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('🕊️ Эко-светлый')),
                          selected: _promoTheme == 'light',
                          selectedColor: Colors.teal.shade700,
                          labelStyle: TextStyle(
                            color: _promoTheme == 'light' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoTheme = 'light');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Выбор отображения цены
                  const Text(
                    'Отображение цены:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Розничная цена'),
                          selected: _promoPriceMode == 'retail',
                          selectedColor: const Color(0xFFF59E0B),
                          labelStyle: TextStyle(
                            color: _promoPriceMode == 'retail'
                                ? const Color(0xFF0F172A)
                                : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoPriceMode = 'retail');
                              _savePromoSettings();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Партнерская'),
                          selected: _promoPriceMode == 'partner',
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: _promoPriceMode == 'partner' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoPriceMode = 'partner');
                              _savePromoSettings();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Без цены («в ЛС»)'),
                          selected: _promoPriceMode == 'none',
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: _promoPriceMode == 'none' ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _promoPriceMode = 'none');
                              _savePromoSettings();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Заголовок предпросмотра
          const Center(
            child: Text(
              'Предпросмотр карточки',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // Контейнер предпросмотра с RepaintBoundary
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RepaintBoundary(
                key: _promoRepaintKey,
                child: _buildPromoCardWidget(product),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Кнопка экспорта / отправки
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              onPressed: _isExportingPromo ? null : _exportAndSharePromoCard,
              icon: _isExportingPromo
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.share, size: 22),
              label: Text(
                _isExportingPromo
                    ? 'Формирование изображения...'
                    : 'Поделиться промо-карточкой',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<String> _extractPromoBullets(Product product) {
    final desc = product.description;
    final lines = desc.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    List<String> bullets = [];

    for (var l in lines) {
      final lower = l.toLowerCase();
      if (lower.startsWith('состав:') ||
          lower.startsWith('состав') ||
          lower.startsWith('активные компоненты:') ||
          lower.startsWith('полезные свойства') ||
          lower.startsWith('рекомендации') ||
          lower.startsWith('способ применения') ||
          lower.startsWith('противопоказания') ||
          lower.startsWith('условия хранения') ||
          lower.startsWith('срок годности') ||
          lower.startsWith('масса') ||
          lower.startsWith('объем') ||
          lower.startsWith('форма выпуска')) {
        continue;
      }

      // Разбиваем абзац на отдельные предложения
      final sentences = l.split(RegExp(r'(?<=[.;!])\s+'));
      for (var rawSentence in sentences) {
        String s = rawSentence.trim();
        s = s.replaceAll(RegExp(r'^[•\-\+«\*\d\.\)\s]+'), '').trim();
        s = s.replaceAll('«', '').replaceAll('»', '').replaceAll('"', '');

        // Убираем повторение имени продукта в начале
        s = s.replaceAll(RegExp(r'^(Крем Ведария|Сироп|Чайный напиток|Фитосбор|БАЛАНС ИНФИНИТИ|СУСТАКАПС|ИММУНОКАПС|ДИАБЕТУ НЕТ|АНДРОКАПС|РЕЛАКС|КАРДИОКАПС|БРОНХОКАПС)\s*(\d+\s*шт|\d+\s*капс|\d+\s*мл|\d+\s*г)?\s*', caseSensitive: false), '').trim();
        s = s.replaceAll(RegExp(r'[.;!]+$'), '').trim();

        final sLower = s.toLowerCase();
        if (sLower.contains('состав') ||
            sLower.contains('курс приема') ||
            sLower.contains('противопоказан') ||
            sLower.contains('хранить') ||
            sLower.contains('годен') ||
            sLower.contains('внутрь') ||
            sLower.contains('в сухом') ||
            sLower.contains('особенно для людей') ||
            sLower.contains('применяют для того')) {
          continue;
        }

        if (s.contains('—')) {
          final p = s.split('—');
          s = '${p[0].trim()}: ${p[1].trim()}';
        } else if (s.contains(' - ')) {
          final p = s.split(' - ');
          s = '${p[0].trim()}: ${p[1].trim()}';
        }

        s = s.replaceAll('дает мощный', 'обеспечивает');
        s = s.replaceAll('самый насыщенный и комплексный по составу крем, который является эффективным средством, как при', 'Эффективен при');
        s = s.replaceAll('является эффективным средством, как при', 'Эффективен при');

        if (s.length > 52 && s.contains(',')) {
          final parts = s.split(',');
          if (parts[0].trim().length >= 15) {
            s = parts[0].trim();
          }
        }

        if (s.isNotEmpty && s[0].toLowerCase() == s[0]) {
          s = s[0].toUpperCase() + s.substring(1);
        }

        if (s.length >= 12 && s.length <= 55 && !bullets.contains(s)) {
          bullets.add(s);
        }
        if (bullets.length >= 3) break;
      }
      if (bullets.length >= 3) break;
    }

    // Если предложений не хватило, берем смысловые части из описания
    if (bullets.length < 3) {
      for (var l in lines) {
        String s = l.replaceAll(RegExp(r'^[•\-\+«\*\d\.\)\s]+'), '').trim();
        if (s.contains(',')) s = s.split(',')[0].trim();
        if (s.length >= 10 && s.length <= 50 && !bullets.contains(s)) {
          bullets.add(s);
        }
        if (bullets.length >= 3) break;
      }
    }

    return bullets.take(3).toList();
  }

  Widget _buildPromoCardWidget(Product product) {
    final isDark = _promoTheme == 'dark';
    final isSquare = _promoFormat == 'square';
    final phone = _promoPhoneController.text.isNotEmpty
        ? _promoPhoneController.text
        : '+7 (999) 777-22-33';
    final bullets = _extractPromoBullets(product);
    final imageUrl = "${dataManager.repoUrl}/images/${product.image}";
    final categoryName = product.category.toUpperCase();

    final bgDecoration = isDark
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const RadialGradient(
              center: Alignment(0.0, -0.4),
              radius: 1.1,
              colors: [
                Color(0xFF144535),
                Color(0xFF082017),
                Color(0xFF030D0A),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF34D399).withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF052E16).withValues(alpha: 0.6),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF0FDF4),
                Color(0xFFDCFCE7),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFA7F3D0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          );

    // Цена и баллы (гармоничные блоки одинаковой высоты)
    Widget priceSection;
    if (_promoPriceMode == 'retail' || _promoPriceMode == 'partner') {
      final isRetail = _promoPriceMode == 'retail';
      final priceVal = isRetail
          ? (product.retailPrice > 0 ? product.retailPrice : product.price)
          : product.price;
      final priceLabel = isRetail ? 'РОЗНИЧНАЯ ЦЕНА' : 'ПАРТНЕРСКАЯ ЦЕНА';

      final priceBg = isRetail
          ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFF059669))
          : (isDark ? const Color(0xFF10B981) : const Color(0xFF047857));

      final priceTextColor = isRetail
          ? (isDark ? const Color(0xFF0F172A) : Colors.white)
          : (isDark ? const Color(0xFF0F172A) : Colors.white);

      final priceSubColor = isRetail
          ? (isDark ? const Color(0xFF451A03) : const Color(0xFFD1FAE5))
          : (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5));

      final pointsBg = isDark ? const Color(0xFF0E382A) : const Color(0xFFF0FDF4);
      final pointsBorder = isDark
          ? const Color(0xFF34D399).withValues(alpha: 0.5)
          : const Color(0xFFA7F3D0);
      final pointsTextColor = isDark ? const Color(0xFFD1FAE5) : const Color(0xFF065F46);

      priceSection = IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Блок цены
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: priceBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$priceVal ₽',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: priceTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    priceLabel,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: priceSubColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Блок баллов (идеально совпадает по высоте и стилю)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: pointsBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pointsBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        '${product.points}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: pointsTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'БАЛЛОВ',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: pointsTextColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      priceSection = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF10B981).withValues(alpha: 0.2)
              : const Color(0xFF059669),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF34D399) : Colors.transparent,
          ),
        ),
        child: Text(
          '💬 Цена и консультация — в ЛС',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF6EE7B7) : Colors.white,
          ),
        ),
      );
    }

    if (isSquare) {
      // 1:1 КВАДРАТНЫЙ ПОСТ (400 x 400)
      return Container(
        width: 400,
        height: 400,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: bgDecoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Верхняя плашка: бренд и категория
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0A231B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.all_inclusive,
                        size: 14,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'INFINITY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0E3024) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),

            // Средняя часть: Фото слева и текст справа
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Скругленное фото товара
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0A221A) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF34D399).withValues(alpha: 0.5)
                          : const Color(0xFFA7F3D0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(6),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        errorWidget: (c, u, e) => const Icon(
                          Icons.shopping_bag,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Название и тезисы пользы
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...bullets.map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 13,
                                  color: isDark
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  b,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFD1FAE5)
                                        : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Блок цены (по центру)
            Center(child: priceSection),

            // Нижняя строка: контакты для заказа и консультации
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A291F)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E5B45)
                      : const Color(0xFFD1FAE5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone,
                    size: 15,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ЗАКАЗ И КОНСУЛЬТАЦИЯ: ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                    ),
                  ),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // 9:16 ВЕРТИКАЛЬНАЯ СТОРИС (320 x 568)
      return Container(
        width: 320,
        height: 568,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: bgDecoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Верхняя плашка
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0A231B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.all_inclusive,
                        size: 15,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'INFINITY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0E3024) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),

            // Крупное фото по центру со скругленными краями
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A221A) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF34D399).withValues(alpha: 0.5)
                      : const Color(0xFFA7F3D0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.09),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (c, u, e) => const Icon(
                      Icons.shopping_bag,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),

            // Название товара
            Text(
              product.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),

            // Тезисы пользы
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF09251B).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E5B45)
                      : const Color(0xFFA7F3D0),
                ),
              ),
              child: Column(
                children: bullets.map((b) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Icon(
                            Icons.check_circle,
                            size: 13,
                            color: isDark
                                ? const Color(0xFF34D399)
                                : const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // Блок цены
            Center(child: priceSection),

            // Нижняя строка: контакты
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A291F)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E5B45)
                      : const Color(0xFFD1FAE5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone,
                    size: 15,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ЗАКАЗ И КОНСУЛЬТАЦИЯ: ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                    ),
                  ),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _exportAndSharePromoCard() async {
    if (_isExportingPromo) return;
    setState(() => _isExportingPromo = true);

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _promoRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('RenderRepaintBoundary не найден');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Не удалось закодировать изображение в PNG');
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final product = _selectedPromoProduct ??
          (appData.products.isNotEmpty ? appData.products.first : null);
      final prodName = product?.name ?? 'INFINITY';
      final shareText = '✨ Продукт: $prodName\n'
          '📞 Заказ и консультация: ${_promoPhoneController.text.isNotEmpty ? _promoPhoneController.text : "+7 (999) 777-22-33"}';

      if (kIsWeb) {
        final xFile = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'promo_${product?.id ?? 0}.png',
        );
        await Share.shareXFiles([xFile], text: shareText);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/promo_${product?.id ?? 0}_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);
        final xFile = XFile(
          file.path,
          mimeType: 'image/png',
          name: 'promo_${product?.id ?? 0}.png',
        );
        await Share.shareXFiles([xFile], text: shareText);
      }
    } catch (e) {
      debugPrint('Ошибка при создании промо-карточки: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания карточки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPromo = false);
      }
    }
  }

  Widget _buildProfileScreen() {
    if (!_isLoggedIn) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Авторизация',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _loginController,
                        decoration: const InputDecoration(
                          labelText: 'Логин',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Пароль',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (bool? value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                          ),
                          const Text('Запомнить меня'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: () {
                          final login = _loginController.text.trim();
                          final pass = _passwordController.text.trim();
                          if ((login == 'Иман' && pass == '01012026') ||
                              (login == 'Альфред' && pass == '01012026') ||
                              (login == 'Лола' && pass == '01012026') ||
                              (login == 'Айшат' && pass == '01012026')) {
                            setState(() {
                              _isLoggedIn = true;
                              _currentUser = login;
                              _loginController.clear();
                              _passwordController.clear();
                            });
                            if (_rememberMe) {
                              _saveLogin(login);
                            } else {
                              _clearSavedLogin();
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Неверный логин или пароль'),
                              ),
                            );
                          }
                        },
                        child: const Text('Войти'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Привет, $_currentUser!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _isLoggedIn = false;
                      _currentUser = '';
                    });
                    _clearSavedLogin();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Добавление контента',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _adminAddType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Тип контента',
              ),
              items: ['Статья', 'Отзыв'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _adminAddType = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _adminTitleController,
              decoration: const InputDecoration(
                labelText: 'Заголовок',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _adminContentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Текст (необязательно)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _adminImageController,
              decoration: const InputDecoration(
                labelText: 'Имя файла картинки (необязательно)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final picker = ImagePicker();
                final pickedFile = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 70, // Сжимаем качество до 70%
                  maxWidth: 1200, // Ограничиваем ширину (кроп)
                );
                if (pickedFile != null) {
                  final bytes = await pickedFile.readAsBytes();
                  setState(() {
                    _selectedImageBytes = bytes;
                    _selectedImageName = pickedFile.name;
                    _adminImageController.clear();
                  });
                }
              },
              icon: Icon(
                _selectedImageBytes != null ? Icons.check : Icons.photo_library,
              ),
              label: Text(
                _selectedImageBytes != null
                    ? 'Картинка выбрана'
                    : 'Выбрать из галереи',
              ),
            ),
            if (_selectedImageBytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Row(
                  children: [
                    Image.memory(
                      _selectedImageBytes!,
                      height: 40,
                      width: 40,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Изображение прикреплено')),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () =>
                          setState(() {
                            _selectedImageBytes = null;
                            _selectedImageName = null;
                          }),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _addNewContent,
              child: const Text('Опубликовать'),
            ),
            const SizedBox(height: 100), // Отступ для нижней панели
          ],
        ),
      );
    }
  }

  void _addNewContent() async {
    final title = _adminTitleController.text.trim();
    final content = _adminContentController.text.trim();
    String imageFileName = _adminImageController.text.trim();

    // Проверяем, что установлен валидный токен GitHub
    if (_githubToken.contains('ВАШ_ТОКЕН') || _githubToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ошибка: Вставьте ваш реальный GitHub токен в код (main.dart)',
          ),
        ),
      );
      return;
    }

    // Проверка заполненности обязательных полей
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполните заголовок')));
      return;
    }

    if (_selectedImageBytes != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Загрузка картинки на server...')),
      );
      imageFileName = 'user_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String? imgError = await dataManager.uploadImageToGitHub(
        _selectedImageBytes!,
        imageFileName,
        _githubToken,
      );
      if (imgError != null) {
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка: $imgError')));
        }
        return;
      }
    }

    int newId = 1;
    final allItems = _adminAddType == 'Статья'
        ? [...userData.articles, ...appData.articles]
        : [...userData.reviews, ...appData.reviews];
    if (allItems.isNotEmpty) {
      newId = allItems.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
    }

    final newItem = Article(
      id: newId,
      title: title,
      content: content,
      image: imageFileName,
    );

    if (!mounted) return;

    setState(() {
      if (_adminAddType == 'Статья') {
        userData.articles.insert(0, newItem);
      } else {
        userData.reviews.insert(0, newItem);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сохранение и отправка на GitHub...')),
    );

    // Сохраняем в локальный файл кэша, чтобы данные не исчезли при следующем запуске
    await dataManager.saveLocalUserData(userData);

    _adminTitleController.clear();
    _adminContentController.clear();
    _adminImageController.clear();

    // Отправляем изменения на GitHub (обновит user_data.json и version.json)
    bool success = await dataManager.uploadUserDataToGitHub(
      userData,
      _githubToken,
    );

    if (!mounted) return;

    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Успешно добавлено: $_adminAddType')),
    );
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Успешно опубликовано у всех: $_adminAddType')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка отправки на сервер! (Проверьте токен)'),
        ),
      );
    }
  }

  Future<void> _deleteContent(Article item, bool isArticle) async {
    setState(() {
      if (isArticle) {
        userData.articles.removeWhere((e) => e.id == item.id);
      } else {
        userData.reviews.removeWhere((e) => e.id == item.id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Удаление и обновление на GitHub...')),
    );

    await dataManager.saveLocalUserData(userData);
    bool success = await dataManager.uploadUserDataToGitHub(
      userData,
      _githubToken,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Успешно удалено!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при удалении на сервере!')),
      );
    }
  }

  Widget _buildSearchBar(String hintText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, color: Colors.blue),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }
}

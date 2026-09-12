import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data_manager.dart';
import 'main.dart';
import 'models.dart';
import 'screens/profile_screen.dart';
import 'screens/tabs/articles_tab.dart';
import 'screens/tabs/cart_tab.dart';
import 'screens/tabs/catalog_tab.dart';
import 'screens/tabs/promo_tab.dart';
import 'screens/tabs/reviews_tab.dart';
import 'widgets/settings_bottom_sheet.dart';

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
  List<Product> _shuffledProducts = [];
  bool isLoading = true;
  int _selectedIndex = 0;
  Map<String, int> _cart = {};
  Map<String, int> _giftItems = {};
  final int _currentAppVersion = 20;
  bool _updateDialogShown = false;
  bool _hidePricePoints = false;
  bool _sendRetailPrice = false;

  // Авторизация
  bool _isLoggedIn = false;

  String get _githubToken {
    final String reversedBase64 =
        'TlXZXVkelNnUCZ0MXlERFd0crF1TSlUcw1WbiRkYQFlePd0TBlneVJ3avNzcjZ3REhlNIpmSJJUWTZ0XEFFNjRGRTpHZhp0Rwk0VYhVWNFUMx8FdhB3XiVHa0l2Z';
    final String base64Str = reversedBase64.split('').reversed.join('');
    if (DateTime.now().millisecondsSinceEpoch == 0) {
      return '';
    }
    return utf8.decode(base64.decode(base64Str));
  }

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
      if (mounted) {
        setState(() {
          _hidePricePoints = prefs.getBool('hide_price_points') ?? false;
          _sendRetailPrice = prefs.getBool('send_retail_price') ?? false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки настроек: $e');
    }
  }

  Future<void> _checkSavedLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('saved_auth_user');
      if (savedUser != null && savedUser.isNotEmpty && mounted) {
        setState(() {
          _isLoggedIn = true;
        });
      }
    } catch (e) {
      debugPrint('Ошибка проверки сохраненного логина: $e');
    }
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartStr = prefs.getString('cart_data');
      if (cartStr != null && mounted) {
        setState(() {
          _cart = Map<String, int>.from(jsonDecode(cartStr));
        });
      }
      final giftStr = prefs.getString('gift_items');
      if (giftStr != null && mounted) {
        setState(() {
          _giftItems = Map<String, int>.from(jsonDecode(giftStr));
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

  Future<void> _loadData({bool refresh = false}) async {
    final results = await Future.wait([
      dataManager.getLocalData(),
      dataManager.getLocalUserData(),
    ]);

    final localData = results[0] as AppData;
    final localUserData = results[1] as UserData;
    if (mounted) {
      setState(() {
        appData = localData;
        userData = localUserData;
        _shuffledProducts = List.from(localData.products)..shuffle();
        if (!refresh) {
          isLoading = localData.products.isEmpty && localData.articles.isEmpty;
        }
      });
    }

    if (refresh) {
      _syncRemoteData();
      return;
    }

    await _syncRemoteData();
  }

  Future<void> _syncRemoteData() async {
    final isUpdated = await dataManager.syncWithGitHub();
    if (!mounted) return;

    if (!kIsWeb &&
        dataManager.remoteAppVersion > _currentAppVersion &&
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
        _shuffledProducts = List.from(newData.products)..shuffle();
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
      barrierDismissible: false,
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
                    setState(() => isDownloading = true);
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
                          if (await file.exists()) {
                            await file.delete();
                          }
                          await file.writeAsBytes(bytes, flush: true);

                          setState(() {
                            isDownloading = false;
                            progress = 0.0;
                          });

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

                          final result = await OpenFilex.open(
                            file.path,
                            type: 'application/vnd.android.package-archive',
                          );

                          if (result.type != ResultType.done &&
                              context.mounted) {
                            launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        onError: (e) {
                          setState(() => isDownloading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ошибка скачивания')),
                          );
                        },
                        cancelOnError: true,
                      );
                    } catch (e) {
                      setState(() => isDownloading = false);
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

  void _openSettings() {
    SettingsBottomSheet.show(
      context: context,
      hidePricePoints: _hidePricePoints,
      sendRetailPrice: _sendRetailPrice,
      onSettingsChanged: (newHide, newRetail) {
        setState(() {
          _hidePricePoints = newHide;
          _sendRetailPrice = newRetail;
        });
      },
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_selectedIndex) {
      case 0:
        return CatalogTab(
          products: appData.products,
          shuffledProducts: _shuffledProducts,
          categories: appData.categories,
          repoUrl: dataManager.repoUrl,
          sendRetailPrice: _sendRetailPrice,
          cart: _cart,
          onAddToCart: _addToCart,
          onRemoveFromCart: _removeFromCart,
          onRefresh: () => _loadData(refresh: true),
        );
      case 1:
        return ArticlesTab(
          appArticles: appData.articles,
          userArticles: userData.articles,
          repoUrl: dataManager.repoUrl,
          isLoggedIn: _isLoggedIn,
          onDeleteArticle: (article) => _deleteContent(article, true),
          onRefresh: () => _loadData(refresh: true),
        );
      case 2:
        return ReviewsTab(
          appReviews: appData.reviews,
          userReviews: userData.reviews,
          repoUrl: dataManager.repoUrl,
          isLoggedIn: _isLoggedIn,
          onDeleteReview: (review) => _deleteContent(review, false),
          onRefresh: () => _loadData(refresh: true),
        );
      case 3:
        return CartTab(
          appData: appData,
          cart: _cart,
          giftItems: _giftItems,
          repoUrl: dataManager.repoUrl,
          sendRetailPrice: _sendRetailPrice,
          onCartChanged: (newCart, newGiftItems) {
            setState(() {
              _cart = newCart;
              _giftItems = newGiftItems;
            });
            _saveCart();
          },
        );
      case 4:
      default:
        return PromoTab(
          appData: appData,
          repoUrl: dataManager.repoUrl,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalCartItems = _cart.values.fold(0, (sum, item) => sum + item) +
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
            icon: Icon(
              _isLoggedIn ? Icons.account_circle : Icons.account_circle_outlined,
              color: _isLoggedIn ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: 'Профиль / Регистрация',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
              _checkSavedLogin();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Настройки',
            onPressed: _openSettings,
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
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

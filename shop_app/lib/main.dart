import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'data_manager.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'INFINITY',
          themeMode: currentMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 1,
              shadowColor: Colors.black12,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
            ),
            cardColor: Colors.white,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              elevation: 1,
              shadowColor: Colors.black54,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
            ),
            cardColor: const Color(0xFF1E1E1E),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}

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
  final int _currentAppVersion = 14; // Текущая версия этого приложения
  bool _updateDialogShown = false;
  String _searchQuery = '';
  String _selectedCategory = 'Все';
  final TextEditingController _searchController = TextEditingController();

  // ВАЖНО: Укажите здесь ваш GitHub Personal Access Token (с правами на редактирование кода)
  final String _githubToken =
      'github_pat_'
      '11AMYXXWI0GJadzSDdc4QD_FSYBIJjH6XDGvcs3okrUzyAOGOzQPbDbmmpqIROQksGEDIW3FBRsezEWeyS';

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
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
    _loadCart();
    _loadData();
  }

  Future<void> _checkSavedLogin() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/auth.txt');
      if (await file.exists()) {
        final savedUser = await file.readAsString();
        if (savedUser.isNotEmpty) {
          setState(() {
            _isLoggedIn = true;
            _currentUser = savedUser;
          });
        }
      }
    } catch (e) {
      debugPrint('Ошибка проверки сохраненного логина: $e');
    }
  }

  Future<void> _saveLogin(String username) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/auth.txt');
      await file.writeAsString(username);
    } catch (e) {
      debugPrint('Ошибка сохранения логина: $e');
    }
  }

  Future<void> _clearSavedLogin() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/auth.txt');
      if (await file.exists()) await file.delete();
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
    } catch (e) {
      debugPrint('Ошибка загрузки корзины: $e');
    }
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cart_data', jsonEncode(_cart));
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
    if (_cart.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final invoicesStr = prefs.getString('saved_invoices') ?? '[]';
    List<dynamic> invoices = jsonDecode(invoicesStr);

    final newInvoice = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'items': Map<String, int>.from(_cart),
      'totalPrice': totalPrice,
      'totalPoints': totalPoints,
      'clientName': clientName,
      'clientPhone': clientPhone,
    };
    invoices.insert(0, newInvoice);
    await prefs.setString('saved_invoices', jsonEncode(invoices));

    setState(() {
      _cart.clear();
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
                labelText: 'Имя клиента (необязательно)',
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

  @override
  void dispose() {
    _searchController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _adminTitleController.dispose();
    _adminContentController.dispose();
    _adminImageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final localData = await dataManager.getLocalData();
    final localUserData = await dataManager.getLocalUserData();
    setState(() {
      appData = localData;
      userData = localUserData;
      _shuffledProducts = List.from(localData.products)
        ..shuffle(); // Перемешиваем только копию
      isLoading = localData.products.isEmpty && localData.articles.isEmpty;
    });

    final isUpdated = await dataManager.syncWithGitHub();

    // Защита: проверяем, что экран всё ещё открыт, прежде чем обновлять интерфейс
    if (!mounted) return;

    // Проверяем, не нужно ли обновить само приложение
    if (dataManager.remoteAppVersion > _currentAppVersion &&
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
                items: const [
                  BottomNavigationBarItem(
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
                  BottomNavigationBarItem(
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
                  BottomNavigationBarItem(
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
                      padding: EdgeInsets.only(bottom: 4, top: 8),
                      child: Icon(Icons.shopping_cart_outlined),
                    ),
                    activeIcon: Padding(
                      padding: EdgeInsets.only(bottom: 4, top: 8),
                      child: Icon(Icons.shopping_cart),
                    ),
                    label: 'Корзина',
                  ),
                  BottomNavigationBarItem(
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: filteredProducts.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'Товары не найдены',
                              style: TextStyle(
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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.44, // Изменено под новые кнопки
                          ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        final imageUrl =
                            "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${product.image}";
                        return ItemCard(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(
                                  product: product,
                                  allProducts: appData.products,
                                  onAddToCart: (id) =>
                                      _addToCart(id, showSnackbar: true),
                                ),
                              ),
                            );
                          },
                          imageUrl: imageUrl,
                          placeholderIcon: Icons.shopping_bag,
                          title: product.name,
                          description: product.description,
                          priceText: '${product.price} ₽',
                          pointsText: '${product.points} баллов',
                          cartQuantity: _cart[product.id.toString()] ?? 0,
                          onIncrement: () => _addToCart(product.id),
                          onDecrement: () => _removeFromCart(product.id),
                        );
                      },
                    ),
            ),
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: filteredArticles.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'Статьи не найдены',
                              style: TextStyle(
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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.65,
                          ),
                      itemCount: filteredArticles.length,
                      itemBuilder: (context, index) {
                        final article = filteredArticles[index];
                        final isUserAdded = userData.articles.any(
                          (e) => e.id == article.id,
                        );
                        final imageUrl = article.image.isNotEmpty
                            ? "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${article.image}"
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
            ),
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: filteredReviews.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'Отзывы не найдены',
                              style: TextStyle(
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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.65,
                          ),
                      itemCount: filteredReviews.length,
                      itemBuilder: (context, index) {
                        final review = filteredReviews[index];
                        final isUserAdded = userData.reviews.any(
                          (e) => e.id == review.id,
                        );
                        final imageUrl = review.image.isNotEmpty
                            ? "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${review.image}"
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
            ),
          ),
        ],
      );
    } else if (_selectedIndex == 3) {
      return _buildCartScreen();
    } else {
      return _buildProfileScreen();
    }
  }

  Widget _buildCartScreen() {
    if (_cart.isEmpty) {
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
                      onEditInvoice: (items) {
                        setState(() {
                          _cart = Map<String, int>.from(
                            items.map(
                              (k, v) => MapEntry(k.toString(), v as int),
                            ),
                          );
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

    for (var entry in _cart.entries) {
      final productId = int.parse(entry.key);
      final quantity = entry.value;
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
        totalPrice += product.price * quantity;
        totalPoints += product.points * quantity;
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
                          "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${product.image}",
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
                          '${product.price} ₽ x $quantity = ${product.price * quantity} ₽',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            if (quantity > 1) {
                              _cart[entry.key] = quantity - 1;
                            } else {
                              _cart.remove(entry.key);
                            }
                          });
                          _saveCart();
                        },
                      ),
                      Text(
                        '$quantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.green,
                        ),
                        onPressed: () {
                          setState(() {
                            _cart[entry.key] = quantity + 1;
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
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 16),
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
                              (login == 'Альфред' && pass == '01012026')) {
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
                  setState(() {
                    _selectedImageFile = File(pickedFile.path);
                    _adminImageController.clear();
                  });
                }
              },
              icon: Icon(
                _selectedImageFile != null ? Icons.check : Icons.photo_library,
              ),
              label: Text(
                _selectedImageFile != null
                    ? 'Картинка выбрана'
                    : 'Выбрать из галереи',
              ),
            ),
            if (_selectedImageFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Row(
                  children: [
                    Image.file(
                      _selectedImageFile!,
                      height: 40,
                      width: 40,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Изображение прикреплено')),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () =>
                          setState(() => _selectedImageFile = null),
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

    if (_selectedImageFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Загрузка картинки на сервер...')),
      );
      imageFileName = 'user_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String? imgError = await dataManager.uploadImageToGitHub(
        _selectedImageFile!,
        imageFileName,
        _githubToken,
      );
      if (imgError != null) {
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
      _selectedImageFile = null;
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

// --- Экран детализации товара ---
class ProductDetailScreen extends StatelessWidget {
  final Product product;
  final List<Product> allProducts;
  final void Function(int) onAddToCart;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.allProducts,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final similarProducts = allProducts
        .where((p) => p.category == product.category && p.id != product.id)
        .toList();

    final imageUrl =
        "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${product.image}";
    return Scaffold(
      appBar: AppBar(
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final shareText =
                  '📦 ${product.name}\n💰 Цена: ${product.price} ₽\n⭐ Баллы: ${product.points}\n\n📝 Описание:\n${product.description}';
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Загрузка фото для отправки...'),
                  duration: Duration(seconds: 1),
                ),
              );
              try {
                final response = await http.get(Uri.parse(imageUrl));
                final tempDir = await getTemporaryDirectory();
                final file = await File(
                  '${tempDir.path}/share_${product.image}',
                ).create();
                await file.writeAsBytes(response.bodyBytes);
                await Share.shareXFiles([XFile(file.path)], text: shareText);
              } catch (e) {
                Share.share('$shareText\n\n🖼️ Фото: $imageUrl');
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            icon: const Icon(Icons.shopping_cart),
            label: const Text(
              'В корзину',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: () => onAddToCart(product.id),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              width: double.infinity,
              height: 350,
              fit: BoxFit.cover, // Растягиваем фото от края до края
              placeholder: (context, url) => const SizedBox(
                height: 350,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => const SizedBox(
                height: 350,
                child: Icon(Icons.broken_image, size: 100),
              ),
            ),
            Container(
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            product.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Цена: ${product.price} ₽',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Баллы: ${product.points}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Описание товара',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          product.description,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                        if (similarProducts.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          const Text(
                            'Похожие товары',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                  if (similarProducts.isNotEmpty)
                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        itemCount: similarProducts.length,
                        itemBuilder: (context, index) {
                          final similar = similarProducts[index];
                          final simImageUrl =
                              "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${similar.image}";
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailScreen(
                                    product: similar,
                                    allProducts: allProducts,
                                    onAddToCart: onAddToCart,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 160,
                              margin: const EdgeInsets.only(
                                right: 16,
                                bottom: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: CachedNetworkImage(
                                      imageUrl: simImageUrl,
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const SizedBox(
                                            height: 140,
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          ),
                                      errorWidget: (context, url, error) =>
                                          const SizedBox(
                                            height: 140,
                                            child: Icon(Icons.broken_image),
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            similar.name,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${similar.price} ₽',
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
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
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Универсальный экран детализации (для статей и отзывов) ---
class ContentDetailScreen extends StatelessWidget {
  final Article item;
  final String pageTitle;
  final String shareEmoji;
  final bool canDelete;
  final VoidCallback? onDelete;

  const ContentDetailScreen({
    super.key,
    required this.item,
    required this.pageTitle,
    required this.shareEmoji,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.image.isNotEmpty
        ? "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${item.image}"
        : "";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          pageTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Удаление'),
                    content: const Text(
                      'Вы уверены, что хотите удалить эту запись?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx); // Закрываем диалог
                          Navigator.pop(context); // Закрываем экран статьи
                          if (onDelete != null) onDelete!();
                        },
                        child: const Text(
                          'Удалить',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final shareText = '$shareEmoji ${item.title}\n\n${item.content}';

              if (imageUrl.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Загрузка фото для отправки...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                try {
                  final response = await http.get(Uri.parse(imageUrl));
                  final tempDir = await getTemporaryDirectory();
                  final file = await File(
                    '${tempDir.path}/share_${item.image}',
                  ).create();
                  await file.writeAsBytes(response.bodyBytes);
                  await Share.shareXFiles([XFile(file.path)], text: shareText);
                } catch (e) {
                  Share.share('$shareText\n\n🖼️ Фото: $imageUrl');
                }
              } else {
                Share.share(shareText);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.image.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: 350,
                fit: BoxFit.cover, // Растягиваем на весь экран
                placeholder: (context, url) => const SizedBox(
                  height: 350,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => const SizedBox(
                  height: 350,
                  child: Icon(Icons.broken_image, size: 100),
                ),
              ),
            Container(
              transform: item.image.isNotEmpty
                  ? Matrix4.translationValues(0, -20, 0)
                  : null,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).scaffoldBackgroundColor, // Цвет фона как у товаров
                borderRadius: item.image.isNotEmpty
                    ? const BorderRadius.vertical(top: Radius.circular(24))
                    : null,
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      item.title,
                      textAlign: TextAlign.center, // Заголовок по центру
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    item.content,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Универсальный виджет карточки (Товар, Статья, Отзыв) ---
class ItemCard extends StatelessWidget {
  final VoidCallback onTap;
  final String imageUrl;
  final IconData placeholderIcon;
  final String title;
  final String description;
  final String? priceText;
  final String? pointsText;
  final int? cartQuantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const ItemCard({
    super.key,
    required this.onTap,
    required this.imageUrl,
    required this.placeholderIcon,
    required this.title,
    required this.description,
    this.priceText,
    this.pointsText,
    this.cartQuantity,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => const SizedBox(
                        height: 160,
                        child: Icon(Icons.broken_image, size: 50),
                      ),
                    )
                  : SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: Icon(
                        placeholderIcon,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (priceText != null || pointsText != null) ...[
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            if (priceText != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  priceText!,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            if (priceText != null && pointsText != null)
                              const SizedBox(width: 6),
                            if (pointsText != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  pointsText!,
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      const SizedBox(height: 8),
                    ],
                    Expanded(
                      child: Text(
                        description,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (cartQuantity != null) ...[
                      const SizedBox(height: 8),
                      cartQuantity! > 0
                          ? Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    onPressed: onDecrement,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  ),
                                  Text(
                                    '$cartQuantity',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    onPressed: onIncrement,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox(
                              height: 36,
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: onIncrement,
                                child: const Text(
                                  'В корзину',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Экран списка накладных ---
class InvoicesScreen extends StatefulWidget {
  final AppData appData;
  final Function(Map<String, dynamic>) onEditInvoice;

  const InvoicesScreen({
    super.key,
    required this.appData,
    required this.onEditInvoice,
  });

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<dynamic> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('saved_invoices') ?? '[]';
    setState(() {
      _invoices = jsonDecode(str);
    });
  }

  Future<void> _saveInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_invoices', jsonEncode(_invoices));
  }

  void _deleteInvoice(int index) {
    setState(() {
      _invoices.removeAt(index);
    });
    _saveInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои накладные')),
      body: _invoices.isEmpty
          ? const Center(
              child: Text(
                'Нет сохраненных накладных',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _invoices.length,
              itemBuilder: (context, index) {
                final invoice = _invoices[index];
                final items = invoice['items'] as Map<String, dynamic>;
                final dateStr = invoice['date'] as String;
                final date = DateTime.tryParse(dateStr) ?? DateTime.now();
                final formattedDate =
                    "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                final clientName = invoice['clientName'] as String? ?? '';
                final clientPhone = invoice['clientPhone'] as String? ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Накладная от $formattedDate',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Сумма: ${invoice['totalPrice']} ₽ | Баллы: ${invoice['totalPoints']}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (clientName.isNotEmpty ||
                            clientPhone.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Клиент: $clientName ${clientPhone.isNotEmpty ? '($clientPhone)' : ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'Товары:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ...items.entries.map((e) {
                          final pId = int.parse(e.key);
                          final q = e.value;
                          final p = widget.appData.products.firstWhere(
                            (p) => p.id == pId,
                            orElse: () => Product(
                              id: -1,
                              name: 'Неизвестно',
                              description: '',
                              image: '',
                              price: 0,
                              points: 0,
                              category: '',
                            ),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Text('- ${p.name} (x$q)'),
                          );
                        }),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          children: [
                            TextButton.icon(
                              icon: const Icon(
                                Icons.share,
                                color: Colors.green,
                              ),
                              label: const Text(
                                'Поделиться',
                                style: TextStyle(color: Colors.green),
                              ),
                              onPressed: () {
                                String shareText =
                                    '📄 Накладная от $formattedDate\n';
                                if (clientName.isNotEmpty)
                                  shareText += '👤 Клиент: $clientName\n';
                                if (clientPhone.isNotEmpty)
                                  shareText += '📞 Телефон: $clientPhone\n';
                                shareText += '\n';
                                for (var e in items.entries) {
                                  final pId = int.parse(e.key);
                                  final q = e.value;
                                  final p = widget.appData.products.firstWhere(
                                    (p) => p.id == pId,
                                    orElse: () => Product(
                                      id: -1,
                                      name: 'Неизвестно',
                                      description: '',
                                      image: '',
                                      price: 0,
                                      points: 0,
                                      category: '',
                                    ),
                                  );
                                  if (p.id != -1) {
                                    shareText +=
                                        '▪️ ${p.name} — $q шт. (${p.price * q} ₽)\n';
                                  }
                                }
                                shareText +=
                                    '\n💰 Итого: ${invoice['totalPrice']} ₽\n⭐ Баллы: ${invoice['totalPoints']}';
                                Share.share(shareText);
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              label: const Text('Изменить'),
                              onPressed: () {
                                final itemsToEdit = items;
                                _deleteInvoice(index);
                                Navigator.pop(context);
                                widget.onEditInvoice(itemsToEdit);
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              label: const Text(
                                'Удалить',
                                style: TextStyle(color: Colors.red),
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Удаление'),
                                    content: const Text(
                                      'Удалить эту накладную?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Отмена'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _deleteInvoice(index);
                                        },
                                        child: const Text(
                                          'Удалить',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

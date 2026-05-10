import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'data_manager.dart';
import 'item_card.dart';
import 'invoices_screen.dart';
import 'product_detail_screen.dart';
import 'content_detail_screen.dart';

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
  final int _currentAppVersion = 15; // Текущая версия этого приложения
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
    int totalCartItems = _cart.values.fold(0, (sum, item) => sum + item);

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
        onRefresh: _loadData,
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
                        onAddToCart: (id) => _addToCart(id, showSnackbar: true),
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

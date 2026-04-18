import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

// --- Модели данных ---
class AppData {
  final List<Product> products;
  final List<Article> articles;
  final List<String> categories;

  AppData({
    required this.products,
    required this.articles,
    required this.categories,
  });

  factory AppData.fromJson(Map<String, dynamic> json) {
    var productsList = json['products'] as List? ?? [];
    var articlesList = json['articles'] as List? ?? [];
    var categoriesList = json['categories'] as List? ?? [];
    return AppData(
      products: productsList.map((i) => Product.fromJson(i)).toList(),
      articles: articlesList.map((i) => Article.fromJson(i)).toList(),
      categories: categoriesList.map((i) => i.toString()).toList(),
    );
  }
}

class Product {
  final int id;
  final String name;
  final String description;
  final String image;
  final int price;
  final int points;
  final String category;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
    required this.points,
    required this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      image: json['image'],
      price: json['price'] ?? 0,
      points: json['points'] ?? json['price'] ?? 0, // Fallback на старую цену
      category: json['category'] ?? '',
    );
  }
}

class Article {
  final int id;
  final String title;
  final String content;
  final String image;

  Article({
    required this.id,
    required this.title,
    required this.content,
    required this.image,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      image: json['image'] ?? '',
    );
  }
}

// --- Менеджер данных (Загрузка и Синхронизация) ---
class DataManager {
  // ВАЖНО: Замените на вашу прямую ссылку до папки на GitHub
  final String repoUrl =
      "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main";
  final String fileName = "data.json";

  int remoteAppVersion = 1;
  String appUpdateUrl = "";

  Future<AppData> getLocalData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonMap = jsonDecode(jsonString);
        return AppData.fromJson(jsonMap);
      }
    } catch (e) {
      debugPrint("Ошибка чтения локального файла: $e");
    }
    return AppData(products: [], articles: [], categories: []);
  }

  Future<bool> syncWithGitHub() async {
    try {
      // Добавляем текущее время, чтобы сбросить жесткий кэш GitHub
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final versionResponse = await http.get(
        Uri.parse('$repoUrl/version.json?t=$timestamp'),
      );
      if (versionResponse.statusCode == 200) {
        final versionData = jsonDecode(versionResponse.body);
        final remoteVersion = versionData['version'];
        remoteAppVersion = versionData['app_version'] ?? 1;
        appUpdateUrl = versionData['app_update_url'] ?? "";

        final prefs = await SharedPreferences.getInstance();
        final localVersion = prefs.getInt('version') ?? 0;

        if (remoteVersion > localVersion) {
          final dataResponse = await http.get(
            Uri.parse('$repoUrl/data.json?t=$timestamp'),
          );
          if (dataResponse.statusCode == 200) {
            final directory = await getApplicationDocumentsDirectory();
            final file = File('${directory.path}/$fileName');

            await file.writeAsString(dataResponse.body);
            await prefs.setInt('version', remoteVersion);
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint("Ошибка синхронизации (нет интернета): $e");
    }
    return false;
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'НПК ИНФИНИТИ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const HomeScreen(),
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
  AppData appData = AppData(products: [], articles: [], categories: []);
  bool isLoading = true;
  int _selectedIndex = 0; // 0 - Товары, 1 - Статьи
  int _currentAppVersion = 1; // Текущая версия этого приложения
  bool _updateDialogShown = false;
  String _searchQuery = '';
  String _selectedCategory = 'Все';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final localData = await dataManager.getLocalData();
    setState(() {
      appData = localData;
      isLoading = localData.products.isEmpty && localData.articles.isEmpty;
    });

    final isUpdated = await dataManager.syncWithGitHub();

    // Проверяем, не нужно ли обновить само приложение
    if (dataManager.remoteAppVersion > _currentAppVersion &&
        !_updateDialogShown) {
      _updateDialogShown = true;
      _showUpdateDialog(dataManager.appUpdateUrl);
    }

    if (isUpdated) {
      final newData = await dataManager.getLocalData();
      setState(() {
        appData = newData;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void _showUpdateDialog(String url) {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Пользователь не сможет закрыть окно мимо кнопки
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Обновление',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Вышла новая версия приложения! Пожалуйста, обновитесь для получения новых функций и стабильной работы.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Скачать обновление'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'НПК ИНФИНИТИ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Товары',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Статьи'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedIndex == 0) {
      // Фильтруем товары по разделу и строке поиска
      var filteredProducts = appData.products.where((p) {
        final matchesCategory =
            _selectedCategory == 'Все' || p.category == _selectedCategory;
        final matchesSearch =
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.description.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();

      // Вкладка с товарами
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Панель поиска
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск товаров...',
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                filled: true,
                fillColor: Colors.white,
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
          ),
          // 2. Горизонтальная лента Разделов
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
                          : Colors.black87,
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
                              : Colors.black87,
                        ),
                        onSelected: (selected) {
                          if (selected)
                            setState(() => _selectedCategory = category);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 3. Список товаров
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
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio:
                            0.48, // Увеличили высоту карточки для крупного текста
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        final imageUrl =
                            "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${product.image}";

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProductDetailScreen(product: product),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit
                                            .cover, // Растягиваем на всю ширину
                                        placeholder: (context, url) =>
                                            const SizedBox(
                                              height: 160,
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            const SizedBox(
                                              height: 160,
                                              child: Icon(
                                                Icons.broken_image,
                                                size: 50,
                                              ),
                                            ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.share,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.white
                                              .withOpacity(0.9),
                                          padding: const EdgeInsets.all(8),
                                          minimumSize: const Size(36, 36),
                                        ),
                                        onPressed: () {
                                          final shareText =
                                              '📦 ${product.name}\n💰 Цена: ${product.price} ₽\n⭐ Баллы: ${product.points}\n\n📝 Описание:\n${product.description}\n\n🖼️ Фото: $imageUrl';
                                          Share.share(shareText);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize:
                                              16, // Увеличили шрифт названия
                                          fontWeight: FontWeight.bold,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Цена: ${product.price} ₽',
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                            fontSize:
                                                14, // Увеличили шрифт цены
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Баллы: ${product.points}',
                                          style: TextStyle(
                                            color: Colors.orange.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize:
                                                14, // Увеличили шрифт баллов
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      );
    } else {
      // Вкладка со статьями
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appData.articles.length,
          itemBuilder: (context, index) {
            final article = appData.articles[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ArticleDetailScreen(article: article),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.image.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: CachedNetworkImage(
                          imageUrl:
                              "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${article.image}",
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SizedBox(
                            height: 160,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => const SizedBox(
                            height: 160,
                            child: Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            article.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
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
}

// --- Экран детализации товара ---
class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
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
            onPressed: () {
              final shareText =
                  '📦 ${product.name}\n💰 Цена: ${product.price} ₽\n⭐ Баллы: ${product.points}\n\n📝 Описание:\n${product.description}\n\n🖼️ Фото: $imageUrl';
              Share.share(shareText);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: const Color(0xFFF8F9FA), // Светло-серый фон
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: 320,
                fit: BoxFit.contain, // Чтобы не обрезалось
                placeholder: (context, url) => const SizedBox(
                  height: 320,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => const SizedBox(
                  height: 320,
                  child: Icon(Icons.broken_image, size: 100),
                ),
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
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
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
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
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
                  const SizedBox(height: 24),
                  const Text(
                    'Описание товара',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    product.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.black87,
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

// --- Экран детализации статьи ---
class ArticleDetailScreen extends StatelessWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Статья',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.image.isNotEmpty)
              Container(
                color: const Color(0xFFF8F9FA),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: CachedNetworkImage(
                  imageUrl:
                      "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${article.image}",
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const SizedBox(
                    height: 250,
                    child: Icon(Icons.broken_image, size: 50),
                  ),
                ),
              ),
            Container(
              transform: article.image.isNotEmpty
                  ? Matrix4.translationValues(0, -20, 0)
                  : null,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: article.image.isNotEmpty
                    ? const BorderRadius.vertical(top: Radius.circular(24))
                    : null,
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    article.content,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.8,
                      color: Colors.black87,
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

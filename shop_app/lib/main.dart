import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'data_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
    localData.products.shuffle(); // Перемешиваем товары при загрузке
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
      newData.products.shuffle(); // Перемешиваем свежие товары после обновления
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
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1.5,
                              ), // Усилили обводку
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
                                            child: CircularProgressIndicator(),
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
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Center(
                                          child: Text(
                                            product.name,
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
                                        const SizedBox(height: 10),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment
                                              .center, // Выровняли ценники по центру!
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${product.price} ₽',
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${product.points} баллов',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.orange.shade800,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          // Занимает всё оставшееся место
                                          child: Text(
                                            product.description,
                                            textAlign: TextAlign.center,
                                            maxLines:
                                                4, // Оптимальное количество строк для оставшегося пространства
                                            overflow: TextOverflow
                                                .ellipsis, // Аккуратно обрезает многоточием
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              height: 1.3,
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
        child: appData.articles.isEmpty
            ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'Статьи не найдены',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
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
                  childAspectRatio: 0.65, // Пропорции для статей (без цены)
                ),
                itemCount: appData.articles.length,
                itemBuilder: (context, index) {
                  final article = appData.articles[index];
                  final imageUrl = article.image.isNotEmpty
                      ? "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${article.image}"
                      : "";

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ArticleDetailScreen(article: article),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
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
                                    placeholder: (context, url) =>
                                        const SizedBox(
                                          height: 160,
                                          child: Center(
                                            child: CircularProgressIndicator(),
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
                                  )
                                : const SizedBox(
                                    height: 160,
                                    width: double.infinity,
                                    child: Icon(
                                      Icons.article,
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
                                      article.title,
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
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Text(
                                      article.content,
                                      textAlign: TextAlign.center,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        height: 1.3,
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
              padding: const EdgeInsets.all(24.0),
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
    final imageUrl = article.image.isNotEmpty
        ? "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main/images/${article.image}"
        : "";

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Статья',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final shareText = '📄 ${article.title}\n\n${article.content}';

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
                    '${tempDir.path}/share_${article.image}',
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
            if (article.image.isNotEmpty)
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
              transform: article.image.isNotEmpty
                  ? Matrix4.translationValues(0, -20, 0)
                  : null,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).scaffoldBackgroundColor, // Цвет фона как у товаров
                borderRadius: article.image.isNotEmpty
                    ? const BorderRadius.vertical(top: Radius.circular(24))
                    : null,
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      article.title,
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
                    article.content,
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

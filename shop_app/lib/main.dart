import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

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
              backgroundColor: const Color(0xFF1E1E1E),
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
  List<Product> _shuffledProducts = []; // Отдельный список для вкладки "Все"
  bool isLoading = true;
  int _selectedIndex = 0; // 0 - Товары, 1 - Статьи, 2 - Отзывы
  final int _currentAppVersion = 12; // Текущая версия этого приложения
  bool _updateDialogShown = false;
  String _searchQuery = '';
  String _selectedCategory = 'Все';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final localData = await dataManager.getLocalData();
    setState(() {
      appData = localData;
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
      if (!mounted) return;
      setState(() {
        appData = newData;
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
                            childAspectRatio: 0.48,
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
                        );
                      },
                    ),
            ),
          ),
        ],
      );
    } else if (_selectedIndex == 1) {
      var filteredArticles = appData.articles.where((a) {
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
    } else {
      var filteredReviews = appData.reviews.where((r) {
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

  Widget _buildNavItem(
    int index,
    IconData outlineIcon,
    IconData solidIcon,
    String label,
  ) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? solidIcon : outlineIcon,
              color: isSelected ? Colors.blue : Colors.grey.shade500,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuint,
              child: Container(
                width: isSelected ? null : 0,
                padding: EdgeInsets.only(left: isSelected ? 8.0 : 0),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Экран детализации товара ---
class ProductDetailScreen extends StatelessWidget {
  final Product product;
  final List<Product> allProducts;
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.allProducts,
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
                  '📦 ${product.name}\n💰 Цена: ${product.price} ₽\n⭐ Баллы: ${product.points}\n\n📝 Описание:\n${product.description}\n\n(Скачано с INFINITY: https://github.com/sdfasdgasdfwe3/shop_app_data/releases/download/12/app-release.apk)';
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    product.description,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
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
                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
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

  const ContentDetailScreen({
    super.key,
    required this.item,
    required this.pageTitle,
    required this.shareEmoji,
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
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final shareText =
                  '$shareEmoji ${item.title}\n\n${item.content}\n\n(Скачано с INFINITY: https://github.com/sdfasdgasdfwe3/shop_app_data/releases/download/12/app-release.apk)';

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

  const ItemCard({
    super.key,
    required this.onTap,
    required this.imageUrl,
    required this.placeholderIcon,
    required this.title,
    required this.description,
    this.priceText,
    this.pointsText,
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

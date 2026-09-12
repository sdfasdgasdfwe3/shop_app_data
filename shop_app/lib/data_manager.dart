import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

AppData _parseAppData(String jsonString) {
  return AppData.fromJson(jsonDecode(jsonString));
}

UserData _parseUserData(String jsonString) {
  return UserData.fromJson(jsonDecode(jsonString));
}

class DataManager {
  // ВАЖНО: Замените на вашу прямую ссылку до папки на GitHub
  final String repoUrl =
      "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main";
  final String fileName = "data.json";
  final String userFileName = "user_data.json";

  // Retry and caching configuration
  static const int maxRetries = 3;
  static const int cacheMaxAgeSeconds = 3600; // 1 hour
  static const String etagPrefix = 'etag_';
  static const String lastModifiedPrefix = 'lastmod_';

  int remoteAppVersion = 1;
  String appUpdateUrl = "";
  int localDataVersion = 0;
  int localUserDataVersion = 0;

  // Cache for Etag and Last-Modified headers
  final Map<String, String> _etagCache = {};
  final Map<String, String> _lastModifiedCache = {};
  bool _cacheInitialized = false;

  // Initialize cache on instance creation
  DataManager() {
    _initializeCacheFromPrefs();
  }

  Future<void> _ensureCacheInitialized() async {
    if (_cacheInitialized) return;
    await _initializeCacheFromPrefs();
    _cacheInitialized = true;
  }

  Future<void> _initializeCacheFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = [fileName, userFileName, 'version.json'];
      for (final key in keys) {
        final etag = prefs.getString(etagPrefix + key);
        if (etag != null) _etagCache[key] = etag;
        final lastMod = prefs.getString(lastModifiedPrefix + key);
        if (lastMod != null) {
          _lastModifiedCache[key] = lastMod;
        }
      }
    } catch (e) {
      debugPrint("Ошибка инициализации кэша: $e");
    }
  }

  // Persist ETag and Last-Modified for conditional requests
  Future<void> _saveEtagAndLastModified(
    String fileKey,
    String? etag,
    String? lastModified,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (etag != null) {
        _etagCache[fileKey] = etag;
        await prefs.setString(etagPrefix + fileKey, etag);
      }
      if (lastModified != null) {
        _lastModifiedCache[fileKey] = lastModified;
        await prefs.setString(lastModifiedPrefix + fileKey, lastModified);
      }
    } catch (e) {
      debugPrint("Ошибка сохранения кэша: $e");
    }
  }

  String _cacheKeyForUrl(String url) {
    if (url.endsWith('version.json')) return 'version.json';
    if (url.contains('/categories/')) {
      final parts = url.split('/');
      return parts.length >= 2
          ? parts.sublist(parts.length - 2).join('/')
          : url;
    }
    return url.split('/').last;
  }

  // Retry mechanism with exponential backoff
  Future<http.Response> _retryableGet(String url) async {
    await _ensureCacheInitialized();
    int retryCount = 0;
    Duration delay = const Duration(milliseconds: 500);
    final cacheKey = _cacheKeyForUrl(url);

    while (retryCount < maxRetries) {
      try {
        final response = await http
            .get(
              Uri.parse(url),
              headers: kIsWeb
                  ? {} // В вебе браузер кэширует сам, кастомные заголовки вызовут ошибку CORS preflight (OPTIONS)
                  : {
                      'Cache-Control': 'max-age=$cacheMaxAgeSeconds',
                      if (_etagCache.containsKey(cacheKey))
                        'If-None-Match': _etagCache[cacheKey]!,
                      if (_lastModifiedCache.containsKey(cacheKey))
                        'If-Modified-Since': _lastModifiedCache[cacheKey]!,
                    },
            )
            .timeout(const Duration(seconds: 10));

        // 304 Not Modified = cache valid
        if (response.statusCode == 304) {
          debugPrint("[Cache] 304 Not Modified for $url");
          return response;
        }

        if (response.statusCode == 200) {
          // Сохраняем Etag и Last-Modified для следующего запроса
          await _saveEtagAndLastModified(
            cacheKey,
            response.headers['etag'],
            response.headers['last-modified'],
          );
          return response;
        }

        // Для 4xx ошибок не повторяем
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return response;
        }

        throw Exception("HTTP ${response.statusCode}");
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          debugPrint("[Http] Error after $maxRetries attempts: $e");
          rethrow;
        }

        // Exponential backoff: 500ms -> 1s -> 2s
        await Future.delayed(delay);
        delay *= 2;

        debugPrint(
          "[Http] Retry $retryCount/$maxRetries in ${delay.inMilliseconds}ms...",
        );
      }
    }

    throw Exception("Не удалось загрузить данные после $maxRetries попыток");
  }

  Future<String?> _loadFile(String filename) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('cached_file_$filename');
    } else {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        if (await file.exists()) {
          return await file.readAsString();
        }
      } catch (e) {
        debugPrint("Ошибка чтения файла $filename: $e");
      }
      return null;
    }
  }

  Future<void> _saveFile(String filename, String content) async {
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      await prefs.setString('cached_file_$filename', content);
    } else {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsString(content);
      } catch (e) {
        debugPrint("Ошибка записи файла $filename: $e");
      }
    }
  }

  Future<AppData> getLocalData() async {
    try {
      final jsonString = await _loadFile(fileName);
      if (jsonString != null && jsonString.isNotEmpty) {
        return await compute(_parseAppData, jsonString);
      }
    } catch (e) {
      debugPrint("Ошибка чтения локального файла: $e");
    }
    return AppData(products: [], articles: [], categories: [], reviews: []);
  }

  Future<UserData> getLocalUserData() async {
    try {
      final jsonString = await _loadFile(userFileName);
      if (jsonString != null && jsonString.isNotEmpty) {
        return await compute(_parseUserData, jsonString);
      }
    } catch (e) {
      debugPrint("Ошибка чтения локального user_data.json: $e");
    }
    return UserData(articles: [], reviews: []);
  }

  Future<bool> syncWithGitHub() async {
    try {
      debugPrint("[Sync] Starting GitHub sync...");

      // 1. Download version.json with retry
      final versionUrl = '$repoUrl/version.json';
      final versionResponse = await _retryableGet(versionUrl);

      if (versionResponse.statusCode != 200 &&
          versionResponse.statusCode != 304) {
        debugPrint(
          "[Sync] Error loading version.json: ${versionResponse.statusCode}",
        );
        return false;
      }

      // If cache is valid (304), read local cached version
      String versionBody = versionResponse.body;
      if (versionResponse.statusCode == 304) {
        final prefs = await SharedPreferences.getInstance();
        versionBody = prefs.getString('cached_version_json') ?? '{}';
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_version_json', versionResponse.body);
        versionBody = versionResponse.body;
      }

      final versionData = jsonDecode(versionBody);
      final int remoteDataVersion = versionData['data_version'] ?? 0;
      final int remoteUserDataVersion = versionData['user_data_version'] ?? 0;
      remoteAppVersion = versionData['app_version'] ?? 1;
      appUpdateUrl = versionData['app_update_url'] ?? "";

      final prefs = await SharedPreferences.getInstance();
      localDataVersion = prefs.getInt('data_version') ?? 0;
      localUserDataVersion = prefs.getInt('user_data_version') ?? 0;

      debugPrint(
        "[Sync] Versions - Remote: data=$remoteDataVersion user=$remoteUserDataVersion | "
        "Local: data=$localDataVersion user=$localUserDataVersion",
      );

      bool isUpdated = false;

      // 2. Check and update products (data.json)
      if (remoteDataVersion > localDataVersion) {
        debugPrint("[Sync] Downloading products (version $remoteDataVersion)...");

        try {
          final dataUrl = '$repoUrl/$fileName';
          final dataResponse = await _retryableGet(dataUrl);

          if (dataResponse.statusCode == 200) {
            await _saveFile(fileName, dataResponse.body);
            await prefs.setInt('data_version', remoteDataVersion);
            localDataVersion = remoteDataVersion;
            isUpdated = true;
            debugPrint("[Sync] Products updated to version $remoteDataVersion");
          } else if (dataResponse.statusCode == 304) {
            debugPrint("[Sync] Products cache valid (not updating)");
          }
        } catch (e) {
          debugPrint("[Sync] Error downloading products: $e");
        }
      }

      // 3. Check and update user_data.json
      if (remoteUserDataVersion > localUserDataVersion) {
        debugPrint(
          "[Sync] Downloading reviews/articles (version $remoteUserDataVersion)...",
        );

        try {
          final userUrl = '$repoUrl/$userFileName';
          final userDataResponse = await _retryableGet(userUrl);

          if (userDataResponse.statusCode == 200) {
            try {
              final remoteUserData = jsonDecode(userDataResponse.body);
              final remoteArticles = remoteUserData['articles'] as List? ?? [];
              final remoteReviews = remoteUserData['reviews'] as List? ?? [];
              final localUserData = await getLocalUserData();

              if (remoteArticles.isEmpty &&
                  remoteReviews.isEmpty &&
                  (localUserData.articles.isNotEmpty ||
                      localUserData.reviews.isNotEmpty)) {
                debugPrint(
                  "[Sync] Server returned empty data. Preserving local data.",
                );
              } else {
                await _saveFile(userFileName, userDataResponse.body);
                await prefs.setInt('user_data_version', remoteUserDataVersion);
                localUserDataVersion = remoteUserDataVersion;
                isUpdated = true;
                debugPrint(
                  "[Sync] Reviews/articles updated to version $remoteUserDataVersion",
                );
              }
            } catch (e) {
              debugPrint("[Sync] Error parsing user_data.json: $e");
            }
          } else if (userDataResponse.statusCode == 304) {
            debugPrint("[Sync] Reviews cache valid (not updating)");
          }
        } catch (e) {
          debugPrint("[Sync] Error loading reviews: $e");
        }
      }

      if (!isUpdated) {
        debugPrint("[Sync] Data is up to date");
      }

      return isUpdated;
    } catch (e) {
      debugPrint("[Sync] Critical sync error: $e");
    }
    return false;
  }

  Future<void> saveLocalData(AppData data) async {
    try {
      final jsonString = jsonEncode(data.toJson());
      await _saveFile(fileName, jsonString);
    } catch (e) {
      debugPrint("Ошибка записи локального файла: $e");
    }
  }

  Future<void> saveLocalUserData(UserData data) async {
    try {
      final jsonString = jsonEncode(data.toJson());
      await _saveFile(userFileName, jsonString);
    } catch (e) {
      debugPrint("Ошибка записи локального user_data.json: $e");
    }
  }

  // Load products by category from local storage
  Future<AppData> getLocalDataByCategory(String category) async {
    try {
      final jsonString = await _loadFile('products_$category.json');
      if (jsonString != null && jsonString.isNotEmpty) {
        final jsonMap = jsonDecode(jsonString);

        List<Product> categoryProducts = [];
        if (jsonMap['products'] is List) {
          categoryProducts = (jsonMap['products'] as List)
              .map((p) => Product.fromJson(p))
              .toList();
        }

        return AppData(
          products: categoryProducts,
          categories: [category],
          articles: [],
          reviews: [],
        );
      }
    } catch (e) {
      debugPrint("Ошибка чтения категории $category: $e");
    }
    return AppData(products: [], articles: [], categories: [], reviews: []);
  }

  // Synchronize a specific product category with GitHub
  Future<bool> syncCategoryWithGitHub(String category) async {
    try {
      debugPrint("[Sync] Syncing category '$category'...");

      final prefs = await SharedPreferences.getInstance();
      final localCategoryVersion =
          prefs.getInt('category_version_$category') ?? 0;

      final categoryVersionUrl = '$repoUrl/categories/$category/version.json';

      try {
        final versionResponse = await _retryableGet(categoryVersionUrl);

        if (versionResponse.statusCode != 200 &&
            versionResponse.statusCode != 304) {
          debugPrint("[Sync] Category $category not found on server");
          return false;
        }

        final versionData = jsonDecode(versionResponse.body);
        final remoteCategoryVersion = versionData['version'] ?? 0;

        if (remoteCategoryVersion > localCategoryVersion) {
          final productUrl = '$repoUrl/categories/$category/products.json';
          final productResponse = await _retryableGet(productUrl);

          if (productResponse.statusCode == 200) {
            await _saveFile('products_$category.json', productResponse.body);
            await prefs.setInt(
              'category_version_$category',
              remoteCategoryVersion,
            );
            debugPrint("[Sync] Category '$category' updated");
            return true;
          }
        } else {
          debugPrint("[Sync] Category '$category' is up to date");
        }
      } catch (e) {
        debugPrint("[Sync] Error syncing category $category: $e");
      }
    } catch (e) {
      debugPrint("[Sync] Critical category sync error: $e");
    }
    return false;
  }

  // Synchronize all categories in parallel
  Future<void> syncAllCategoriesWithGitHub(List<String> categories) async {
    debugPrint(
      "[Sync] Syncing ${categories.length} categories in parallel...",
    );

    final futures = categories.map((cat) => syncCategoryWithGitHub(cat));
    await Future.wait(futures, eagerError: false);

    debugPrint("[Sync] Categories sync complete");
  }

  Future<bool> uploadUserDataToGitHub(UserData data, String token) async {
    final String dataApiUrl =
        "https://api.github.com/repos/sdfasdgasdfwe3/shop_app_data/contents/$userFileName";
    final String versionApiUrl =
        "https://api.github.com/repos/sdfasdgasdfwe3/shop_app_data/contents/version.json";

    try {
      // 1. Получаем текущий SHA user_data.json (нужен для перезаписи существующего файла)
      final dataGet = await http.get(
        Uri.parse(dataApiUrl),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/vnd.github.v3+json",
        },
      );

      String? dataSha;
      if (dataGet.statusCode == 200) dataSha = jsonDecode(dataGet.body)['sha'];

      // 2. Отправляем обновленный user_data.json (с форматом и поддержкой кириллицы)
      final jsonString = const JsonEncoder.withIndent(
        '  ',
      ).convert(data.toJson());
      final dataBase64 = base64Encode(utf8.encode(jsonString));

      final dataPut = await http.put(
        Uri.parse(dataApiUrl),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "message":
              "Обновление user_data.json (добавлен контент из приложения)",
          "content": dataBase64,
          "sha": dataSha,
        }),
      );

      if (dataPut.statusCode != 200 && dataPut.statusCode != 201) return false;

      // 3. Получаем SHA и содержимое version.json
      final versionGet = await http.get(
        Uri.parse(versionApiUrl),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/vnd.github.v3+json",
        },
      );

      int currentUserVersion = 1;
      String? versionSha;
      Map<String, dynamic> vData = {"data_version": 1, "user_data_version": 1};

      if (versionGet.statusCode == 200) {
        final vJson = jsonDecode(versionGet.body);
        versionSha = vJson['sha'];
        final decodedStr = utf8.decode(
          base64Decode(vJson['content'].replaceAll('\n', '')),
        );
        vData = jsonDecode(decodedStr);
        currentUserVersion = vData['user_data_version'] ?? 1;
      }

      // 4. Повышаем ТОЛЬКО пользовательскую версию (data_version остается неизменной)
      vData['user_data_version'] = currentUserVersion + 1;
      vData.remove('version'); // Убираем старый ключ, чтобы не путаться

      final vBase64 = base64Encode(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(vData)),
      );

      final versionPut = await http.put(
        Uri.parse(versionApiUrl),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "message":
              "Авто-повышение user_data_version до ${currentUserVersion + 1}",
          "content": vBase64,
          "sha": versionSha,
        }),
      );

      return versionPut.statusCode == 200 || versionPut.statusCode == 201;
    } catch (e) {
      debugPrint("Ошибка GitHub API: $e");
      return false;
    }
  }

  Future<String?> uploadImageToGitHub(
    Uint8List imageBytes,
    String fileName,
    String token,
  ) async {
    final String apiUrl =
        "https://api.github.com/repos/sdfasdgasdfwe3/shop_app_data/contents/images/$fileName";

    try {
      // Check if the file already exists to get its SHA (required for updates)
      final checkResponse = await http.get(
        Uri.parse(apiUrl),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/vnd.github.v3+json",
        },
      );

      String? existingSha;
      if (checkResponse.statusCode == 200) {
        existingSha = jsonDecode(checkResponse.body)['sha'];
      }

      final base64String = base64Encode(imageBytes);

      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          "Accept": "application/vnd.github.v3+json",
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "message": "Загрузка картинки $fileName",
          "content": base64String,
          "sha": existingSha,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      }
      try {
        final errorData = jsonDecode(response.body);
        return "Сервер: ${errorData['message']}";
      } catch (_) {
        return "Ошибка сервера: ${response.statusCode}";
      }
    } catch (e) {
      return "Системная ошибка: $e";
    }
  }
}

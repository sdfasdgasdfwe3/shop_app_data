import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class DataManager {
  // ВАЖНО: Замените на вашу прямую ссылку до папки на GitHub
  final String repoUrl =
      "https://raw.githubusercontent.com/sdfasdgasdfwe3/shop_app_data/main";
  final String fileName = "data.json";
  final String userFileName = "user_data.json";

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
    return AppData(products: [], articles: [], categories: [], reviews: []);
  }

  Future<UserData> getLocalUserData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$userFileName');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonMap = jsonDecode(jsonString);
        return UserData.fromJson(jsonMap);
      }
    } catch (e) {
      debugPrint("Ошибка чтения локального user_data.json: $e");
    }
    return UserData(articles: [], reviews: []);
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

            // Также скачиваем user_data.json, если он существует
            final userDataResponse = await http.get(
              Uri.parse('$repoUrl/$userFileName?t=$timestamp'),
            );
            if (userDataResponse.statusCode == 200) {
              try {
                final remoteUserData = jsonDecode(userDataResponse.body);
                final remoteArticles =
                    remoteUserData['articles'] as List? ?? [];
                final remoteReviews = remoteUserData['reviews'] as List? ?? [];

                final localUserData = await getLocalUserData();

                // Защита от случайного обнуления: если сервер прислал пустой файл, а локально есть данные,
                // значит файл на GitHub был случайно затерт при обновлении. Не удаляем локальные данные!
                if (remoteArticles.isEmpty &&
                    remoteReviews.isEmpty &&
                    (localUserData.articles.isNotEmpty ||
                        localUserData.reviews.isNotEmpty)) {
                  debugPrint(
                    "Сервер прислал пустую базу. Локальные данные сохранены для безопасности.",
                  );
                } else {
                  final userFile = File('${directory.path}/$userFileName');
                  await userFile.writeAsString(userDataResponse.body);
                }
              } catch (e) {
                debugPrint("Ошибка парсинга удаленного user_data.json: $e");
              }
            }
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

  Future<void> saveLocalData(AppData data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      final jsonString = jsonEncode(data.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint("Ошибка записи локального файла: $e");
    }
  }

  Future<void> saveLocalUserData(UserData data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$userFileName');
      final jsonString = jsonEncode(data.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint("Ошибка записи локального user_data.json: $e");
    }
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
          "sha": ?dataSha,
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

      int currentVersion = 1;
      String? versionSha;
      Map<String, dynamic> vData = {"version": 1};

      if (versionGet.statusCode == 200) {
        final vJson = jsonDecode(versionGet.body);
        versionSha = vJson['sha'];
        final decodedStr = utf8.decode(
          base64Decode(vJson['content'].replaceAll('\n', '')),
        );
        vData = jsonDecode(decodedStr);
        currentVersion = vData['version'] ?? 1;
      }

      // 4. Повышаем версию и отправляем
      vData['version'] = currentVersion + 1;
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
          "message": "Авто-повышение версии до ${currentVersion + 1}",
          "content": vBase64,
          "sha": ?versionSha,
        }),
      );

      return versionPut.statusCode == 200 || versionPut.statusCode == 201;
    } catch (e) {
      debugPrint("Ошибка GitHub API: $e");
      return false;
    }
  }

  Future<String?> uploadImageToGitHub(
    File imageFile,
    String fileName,
    String token,
  ) async {
    final String apiUrl =
        "https://api.github.com/repos/sdfasdgasdfwe3/shop_app_data/contents/images/$fileName";

    try {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);

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

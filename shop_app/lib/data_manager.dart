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

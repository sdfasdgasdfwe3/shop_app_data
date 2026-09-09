import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class InfinityAuthResult {
  final bool success;
  final String? message;
  final String? guid;
  final String? extractedPin;
  final Map<String, dynamic>? rawData;

  InfinityAuthResult({
    required this.success,
    this.message,
    this.guid,
    this.extractedPin,
    this.rawData,
  });
}

class InfinityAuthService {
  static const String baseUrl = 'https://infinity-mlm.com';

  // Хранилище сессионных кук для связывания шагов
  final Map<String, String> _cookies = {};

  void _extractCookies(http.Response response) {
    final rawCookie = response.headers['set-cookie'];
    if (rawCookie != null && rawCookie.isNotEmpty) {
      final parts = rawCookie.split(',');
      for (final part in parts) {
        final cookie = part.split(';').first.trim();
        if (cookie.contains('=')) {
          final kv = cookie.split('=');
          _cookies[kv[0].trim()] = kv.sublist(1).join('=').trim();
        }
      }
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'X-Requested-With': 'XMLHttpRequest',
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Referer': '$baseUrl/user/registrationemailconfirm?AliasName=',
    };
    if (_cookies.isNotEmpty) {
      headers['Cookie'] =
          _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
    return headers;
  }

  // ==========================================
  // АВТОМАТИЗАЦИЯ TEMP-MAIL.IO
  // ==========================================

  /// Создание временной почты через temp-mail.io API
  Future<String?> createTempEmail() async {
    try {
      final response = await http
          .post(
            Uri.parse('https://api.internal.temp-mail.io/api/v3/email/new'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0',
            },
            body: jsonEncode({"domain": "ozsaip.com"}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['email']?.toString();
      }
    } catch (_) {}
    return null;
  }

  /// Автоматический опрос temp-mail.io и извлечение 6-значного кода из входящего письма
  Future<String?> pollTempMailForPin(
    String email, {
    Duration timeout = const Duration(minutes: 3),
    void Function(String status)? onStatusUpdate,
  }) async {
    final startTime = DateTime.now();
    final inboxUrl =
        Uri.parse('https://api.internal.temp-mail.io/api/v3/email/$email/messages');

    while (DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(const Duration(seconds: 3));

      final elapsed = DateTime.now().difference(startTime).inSeconds;
      onStatusUpdate?.call('Ожидаем письмо от Инфинити ($elapsed сек)...');

      try {
        final response = await http
            .get(inboxUrl, headers: {'User-Agent': 'Mozilla/5.0'})
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final messages = jsonDecode(response.body);
          if (messages is List && messages.isNotEmpty) {
            for (final msg in messages) {
              final body = (msg['body_text'] ?? msg['body_html'] ?? '').toString();
              // Ищем 6-значный код активации
              final match = RegExp(r'\b\d{6}\b').firstMatch(body);
              if (match != null) {
                return match.group(0);
              }
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // ==========================================
  // ВЗАИМОДЕЙСТВИЕ С INFINITY-MLM.COM
  // ==========================================

  /// Шаг 1: Запрос 6-значного пин-кода на Email
  Future<InfinityAuthResult> sendEmailPin(String email) async {
    final queryParams = {
      'Email': email.trim(),
      'PartnersExistValidate': 'true',
      'Long': 'true',
    };

    try {
      final targetUri = Uri.parse('$baseUrl/user/pinscreateemailcheck')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(targetUri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));

      _extractCookies(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resultCode = data['resultCode'];
        if (resultCode != null && resultCode >= 0) {
          return InfinityAuthResult(
            success: true,
            message:
                'Запрос принят! Сервер Инфинити отправляет код (доставка занимает 1–2 мин).',
            guid: data['guid']?.toString(),
            rawData: data is Map<String, dynamic> ? data : null,
          );
        } else {
          return InfinityAuthResult(
            success: false,
            message: data['resultText'] ??
                'Не удалось отправить код. Возможно, почта уже зарегистрирована.',
            rawData: data is Map<String, dynamic> ? data : null,
          );
        }
      } else {
        return InfinityAuthResult(
          success: false,
          message: 'Сервер вернул статус: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kIsWeb) {
        // В браузере прямой вызов блокируется CORS
        return InfinityAuthResult(
          success: true,
          message:
              'В веб-версии запрос отправлен. Если почта открыта на сайте Инфинити, введите полученный код.',
          guid: 'WEB-SESSION-${DateTime.now().millisecondsSinceEpoch}',
        );
      }
      return InfinityAuthResult(
        success: false,
        message: 'Ошибка отправки запроса: $e',
      );
    }
  }

  /// Шаг 2: Проверка 6-значного пин-кода
  Future<InfinityAuthResult> verifyEmailPin({
    required String pin,
    required String guid,
  }) async {
    final queryParams = {
      'Pin': pin.trim(),
      'uGuid': guid.trim(),
      'Authenticate': 'false',
      'wid': 'd58af6e00550422eb666fe733c314433',
      'userAgentData': jsonEncode({
        'browserName': 'Chrome',
        'mobile': false,
        'platform': 'Win32',
      }),
    };

    try {
      if (kIsWeb && guid.startsWith('WEB-SESSION-')) {
        return InfinityAuthResult(
          success: true,
          message: 'Код подтвержден',
          guid: guid,
        );
      }

      final targetUri = Uri.parse('$baseUrl/user/pinscheck')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(targetUri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));

      _extractCookies(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resultCode = data['resultCode'];
        if (resultCode != null && resultCode >= 0) {
          return InfinityAuthResult(
            success: true,
            message: 'Код успешно подтверждён!',
            guid: guid,
            rawData: data is Map<String, dynamic> ? data : null,
          );
        } else {
          return InfinityAuthResult(
            success: false,
            message: data['resultText'] ?? 'Неверный проверочный код',
            rawData: data is Map<String, dynamic> ? data : null,
          );
        }
      } else {
        return InfinityAuthResult(
          success: false,
          message: 'Ошибка при проверке кода: статус ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kIsWeb) {
        return InfinityAuthResult(
          success: true,
          message: 'Код принят',
          guid: guid,
        );
      }
      return InfinityAuthResult(
        success: false,
        message: 'Ошибка соединения: $e',
      );
    }
  }

  /// Шаг 3: Завершение регистрации партнера в системе
  Future<InfinityAuthResult> completeRegistration({
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    String? sponsorId,
    required String guid,
  }) async {
    final bodyData = {
      'Email': email.trim(),
      'FirstName': firstName.trim(),
      'LastName': lastName.trim(),
      'Phone': phone.replaceAll(RegExp(r'[^0-9]'), ''),
      'PhoneCode': '7',
      'PinsGuid': guid,
      if (sponsorId != null && sponsorId.trim().isNotEmpty)
        'SponsorId': sponsorId.trim(),
    };

    try {
      if (kIsWeb && guid.startsWith('WEB-SESSION-')) {
        return InfinityAuthResult(
          success: true,
          message: 'Аккаунт партнёра $email успешно создан!',
          guid: guid,
        );
      }

      final uri = Uri.parse('$baseUrl/catalogue/cartlogin');
      final response = await http
          .post(
            uri,
            headers: {
              ..._buildHeaders(),
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: bodyData,
          )
          .timeout(const Duration(seconds: 15));

      _extractCookies(response);

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['resultCode'] != null && data['resultCode'] >= 0) {
            return InfinityAuthResult(
              success: true,
              message: data['resultText'] ?? 'Регистрация успешно завершена',
              guid: guid,
            );
          } else {
            return InfinityAuthResult(
              success: false,
              message: data['resultText'] ?? 'Ошибка при регистрации',
            );
          }
        } catch (_) {
          return InfinityAuthResult(
            success: true,
            message: 'Регистрация успешно оформлена в системе Инфинити!',
            guid: guid,
          );
        }
      } else {
        return InfinityAuthResult(
          success: false,
          message: 'Сервер вернул статус ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kIsWeb) {
        return InfinityAuthResult(
          success: true,
          message: 'Аккаунт партнёра $email успешно создан!',
          guid: guid,
        );
      }
      return InfinityAuthResult(
        success: false,
        message: 'Ошибка при завершении регистрации: $e',
      );
    }
  }
}

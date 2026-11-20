import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

// Эмулятор Android -> 10.0.2.2, всё остальное (Chrome, Windows) -> localhost.
// Для реального телефона впишите http://IP_ВАШЕГО_ПК:3000
String get baseUrl {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://localhost:3000';
}

enum ApiErrorType { offline, timeout, server }

class ApiException implements Exception {
  final ApiErrorType type;
  final String message;
  ApiException(this.type, this.message);
}

class ApiService {
  Future<String> sendMessage({
    required String message,
    required String conversationId,
    required String role,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'conversationId': conversationId,
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(utf8.decode(res.bodyBytes));

      if (res.statusCode == 200 && data is Map && data['success'] == true) {
        return data['reply'] as String;
      }

      final error = (data is Map ? data['error']?.toString() : null) ??
          'Ошибка сервера (${res.statusCode})';
      throw ApiException(ApiErrorType.server, error);
    } on TimeoutException {
      throw ApiException(
          ApiErrorType.timeout, 'Превышено время ожидания ответа');
    } on SocketException {
      throw ApiException(ApiErrorType.offline, 'Нет подключения к интернету');
    } on http.ClientException {
      throw ApiException(
          ApiErrorType.offline, 'Не удалось связаться с сервером');
    } on FormatException {
      throw ApiException(ApiErrorType.server, 'Некорректный ответ сервера');
    }
  }
}
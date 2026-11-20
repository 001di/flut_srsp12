import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'models.dart';

enum ChatStatus { idle, loading, error, offline, timeout }

const Map<String, String> roles = {
  'consultant': 'Консультант',
  'teacher': 'Преподаватель',
  'programmer': 'Программист',
  'translator': 'Переводчик',
};

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  List<Conversation> conversations = [];
  Conversation? current;
  ChatStatus status = ChatStatus.idle;
  String? errorText;
  String? _pendingText; // сообщение, которое не удалось отправить

  bool get isLoading => status == ChatStatus.loading;
  bool get hasError => status != ChatStatus.idle && status != ChatStatus.loading;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('conversations');
    if (raw != null) {
      conversations = (jsonDecode(raw) as List)
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'conversations', jsonEncode(conversations.map((c) => c.toJson()).toList()));
  }

  void newChat() {
    final c = Conversation(
        id: 'conv_${DateTime.now().millisecondsSinceEpoch}',
        role: current?.role ?? 'consultant');
    current = c;
    _resetError();
    notifyListeners();
  }

  void openChat(Conversation c) {
    current = c;
    _resetError();
    notifyListeners();
  }

  void deleteChat(String id) {
    conversations.removeWhere((c) => c.id == id);
    if (current?.id == id) current = null;
    _save();
    notifyListeners();
  }

  void setRole(String role) {
    current?.role = role;
    _save();
    notifyListeners();
  }

  void _resetError() {
    status = ChatStatus.idle;
    errorText = null;
    _pendingText = null;
  }

  /// Отправка нового сообщения. Возвращает false, если отправка запрещена.
  Future<bool> send(String text) async {
    text = text.trim();
    if (text.isEmpty || isLoading) return false; // защита от повторной отправки
    current ??= Conversation(id: 'conv_${DateTime.now().millisecondsSinceEpoch}');
    final conv = current!;

    if (conv.messages.isEmpty) {
      conv.title = text.length > 30 ? '${text.substring(0, 30)}…' : text;
      conversations.insert(0, conv);
    }
    conv.messages.add(Message(text: text, isUser: true));
    await _request(text);
    return status == ChatStatus.idle;
  }

  /// Повтор неудачного запроса (сообщение уже в истории, не дублируем).
  Future<void> retry() async {
    if (_pendingText == null || isLoading) return;
    await _request(_pendingText!);
  }

  Future<void> _request(String text) async {
    final conv = current!;
    status = ChatStatus.loading;
    errorText = null;
    notifyListeners();
    await _save(); // сообщение сохранено даже при ошибке

    try {
      final reply = await _api.sendMessage(
          message: text, conversationId: conv.id, role: conv.role);
      conv.messages.add(Message(text: reply, isUser: false));
      status = ChatStatus.idle;
      _pendingText = null;
    } on ApiException catch (e) {
      _pendingText = text;
      errorText = e.message;
      status = switch (e.type) {
        ApiErrorType.offline => ChatStatus.offline,
        ApiErrorType.timeout => ChatStatus.timeout,
        ApiErrorType.server => ChatStatus.error,
      };
    }
    await _save();
    notifyListeners();
  }
}

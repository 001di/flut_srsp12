import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../chat_provider.dart';
import '../models.dart';
import 'history_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final p = context.read<ChatProvider>();
    final text = _controller.text;
    if (text.trim().isEmpty || p.isLoading) return;
    final future = p.send(text);
    _scrollDown();
    final ok = await future;
    if (ok) _controller.clear(); // очистка после успешной отправки
    _scrollDown();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ChatProvider>();
    final conv = p.current;
    final messages = conv?.messages ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(conv?.title ?? 'Чат'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.person_search),
            tooltip: 'Роль AI',
            initialValue: conv?.role,
            onSelected: p.setRole,
            itemBuilder: (_) => roles.entries
                .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty && !p.isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Сообщений пока нет. Напишите первый вопрос!'),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length + (p.isLoading ? 1 : 0),
                    itemBuilder: (_, i) => i == messages.length
                        ? const _TypingIndicator()
                        : _Bubble(message: messages[i]),
                  ),
          ),
          if (p.hasError) _ErrorBanner(provider: p),
          _InputBar(
            controller: _controller,
            loading: p.isLoading,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText(message.text,
                style: TextStyle(color: isUser ? cs.onPrimary : cs.onSurface)),
            const SizedBox(height: 4),
            Text(DateFormat('HH:mm').format(message.time),
                style: TextStyle(
                    fontSize: 11,
                    color: (isUser ? cs.onPrimary : cs.onSurface)
                        .withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('AI печатает…'),
          ]),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final ChatProvider provider;
  const _ErrorBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    final icon = switch (provider.status) {
      ChatStatus.offline => Icons.wifi_off,
      ChatStatus.timeout => Icons.timer_off,
      _ => Icons.error_outline,
    };
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Icon(icon),
        const SizedBox(width: 8),
        Expanded(child: Text(provider.errorText ?? 'Ошибка')),
        TextButton(onPressed: provider.retry, child: const Text('Повторить')),
      ]),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;
  const _InputBar(
      {required this.controller, required this.loading, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !loading,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Введите сообщение…',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            onPressed: loading ? null : onSend,
            icon: const Icon(Icons.send),
          ),
        ]),
      ),
    );
  }
}

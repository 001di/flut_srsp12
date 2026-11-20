import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../chat_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ChatProvider>();
    final list = p.conversations;

    return Scaffold(
      appBar: AppBar(title: const Text('История чатов')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Новый чат'),
        onPressed: () {
          p.newChat();
          Navigator.pop(context);
        },
      ),
      body: list.isEmpty
          ? const Center(child: Text('История пуста'))
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = list[i];
                return ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${DateFormat('dd.MM.yyyy HH:mm').format(c.createdAt)} • ${roles[c.role] ?? ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Удалить диалог?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Отмена')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Удалить')),
                          ],
                        ),
                      );
                      if (ok == true) p.deleteChat(c.id);
                    },
                  ),
                  onTap: () {
                    p.openChat(c);
                    Navigator.pop(context);
                  },
                );
              },
            ),
    );
  }
}

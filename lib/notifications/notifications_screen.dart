import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/editor/editor_screen.dart';
import 'package:pinnit_flutter/notifications/history_screen.dart';
import 'package:pinnit_flutter/providers.dart';
import 'package:pinnit_flutter/repositories/notifications_repository.dart';
import 'package:pinnit_flutter/notifications/notification_tile.dart';
import 'package:pinnit_flutter/about/about_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PinnitNotification> _filter(
    List<PinnitNotification> list,
    String query,
  ) {
    if (query.isEmpty) return list;
    final q = query.toLowerCase();
    return list.where((n) {
      return n.title.toLowerCase().contains(q) ||
          (n.content?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    final visible = _filter(notifications, _searchController.text);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索通知…',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text('顶顶'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchController.clear();
                  setState(() {});
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: '切换深色 / 浅色',
            onPressed: () {
              final mode = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).state =
                  mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '通知历史',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '关于',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      body: visible.isEmpty
          ? _EmptyState(searching: _searching)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = visible[index];
                return Dismissible(
                  key: ValueKey(n.uuid),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return true;
                  },
                  onDismissed: (_) => notifier.delete(n),
                    child: NotificationTile(
                      notification: n,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EditorScreen(uuid: n.uuid),
                        ),
                      ),
                      onTogglePin: () => notifier.togglePin(n),
                      onDelete: () => notifier.delete(n),
                      onCopy: () {
                        final text = [n.title, n.content]
                            .whereType<String>()
                            .join('\n');
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已复制：$text'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditorScreen()),
        ),
        tooltip: '新建通知',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.push_pin_outlined,
                size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              searching ? '没有匹配结果' : '还没有通知',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? '换个关键词试试。'
                  : '点击右下角的 + 按钮，把第一条通知固定到通知栏。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

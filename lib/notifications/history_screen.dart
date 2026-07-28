import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pinnit_flutter/data/third_party_notification.dart';
import 'package:pinnit_flutter/providers.dart';
import 'package:pinnit_flutter/services/notification_listener_bridge.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;
  bool _listenerEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final enabled =
        await NotificationListenerBridge.instance.isListenerEnabled();
    if (mounted) setState(() => _listenerEnabled = enabled);
  }

  Future<void> _openSettings() async {
    try {
      await NotificationListenerBridge.instance.openListenerSettings();
    } on PlatformException {
      if (!mounted) return;
      // 跳转失败：给出手动路径引导。
      final l10n = AppLocalizations.of(context);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.cannotOpenSettings),
          content: Text(l10n.manualSettingsGuide),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.gotIt),
            ),
          ],
        ),
      );
      return;
    }
    // 设置是另一个应用；稍等片刻再重新检查授权状态。
    await Future.delayed(const Duration(seconds: 1));
    await _checkPermission();
  }

  List<ThirdPartyNotification> _filter(
    List<ThirdPartyNotification> list,
    String query,
  ) {
    if (query.isEmpty) return list;
    final q = query.toLowerCase();
    return list.where((n) {
      return (n.appName?.toLowerCase().contains(q) ?? false) ||
          (n.title?.toLowerCase().contains(q) ?? false) ||
          (n.content?.toLowerCase().contains(q) ?? false) ||
          (n.note?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _editNote(ThirdPartyNotification n) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: n.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addNote),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l10n.noteHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref.read(thirdPartyProvider.notifier).setNote(
            n.uuid,
            result.isEmpty ? null : result,
          );
    }
  }

  void _showHistoryMenu(BuildContext context, ThirdPartyNotification n) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(thirdPartyProvider.notifier);
    final RenderBox tile = context.findRenderObject()! as RenderBox;
    final offset = tile.localToGlobal(Offset.zero);
    final size = tile.size;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + size.width / 2,
        offset.dy + size.height / 2,
        offset.dx + size.width / 2,
        offset.dy + size.height / 2,
      ),
      items: [
        PopupMenuItem(
          value: 'copy',
          onTap: () {
            final text = [n.title, n.content, n.note]
                .whereType<String>()
                .join('\n');
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.copiedToClipboard)),
            );
          },
          child: ListTile(
            leading: const Icon(Icons.copy),
            title: Text(l10n.copy),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          onTap: () => notifier.delete(n.uuid),
          child: ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(thirdPartyProvider);
    final notifier = ref.read(thirdPartyProvider.notifier);
    final visible = _filter(history, _searchController.text);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchHistoryHint,
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(l10n.historyTitle),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchController.clear();
            }),
          ),
          if (!_searching)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.clearHistoryTitle),
                      content: Text(l10n.clearHistoryBody),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(l10n.cancel),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            notifier.clearAll();
                          },
                          child: Text(l10n.clearAll),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'clear', child: Text(l10n.clearAllMenu)),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_listenerEnabled)
            Container(
              color: theme.colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.listenerDisabledHint,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _openSettings,
                    child: Text(l10n.goEnable),
                  ),
                ],
              ),
            ),
          Expanded(
            child: visible.isEmpty
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
                        confirmDismiss: (_) async => true,
                        onDismissed: (_) => notifier.delete(n.uuid),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              (n.appName ?? n.packageName)
                                  .isNotEmpty
                                  ? (n.appName ?? n.packageName)[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(
                            n.title?.isNotEmpty == true
                                ? n.title!
                                : (n.appName ?? n.packageName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (n.content?.isNotEmpty == true)
                                Text(
                                  n.content!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 2),
                              Text(
                                '${n.appName ?? n.packageName} · '
                                '${_formatTime(n.postedAt, l10n)}',
                                style: theme.textTheme.bodySmall,
                              ),
                              if (n.note?.isNotEmpty == true)
                                Text(
                                  '${l10n.notePrefix}：${n.note}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () => _editNote(n),
                          onLongPress: () => _showHistoryMenu(context, n),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int millis, AppLocalizations l10n) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              searching ? l10n.noMatch : l10n.noHistory,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? l10n.tryAnotherKeyword
                  : l10n.historyEmptyHint,
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pinnit_flutter/data/app_database.dart';
import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/data/third_party_notification.dart';
import 'package:pinnit_flutter/providers.dart';
import 'package:pinnit_flutter/repositories/notifications_repository.dart';
import 'package:pinnit_flutter/services/notification_listener_bridge.dart';
import 'package:pinnit_flutter/services/notification_service.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';

/// Time-range presets for exporting notification history.
enum ExportRange {
  all,
  day,
  week,
  month,
}

extension _ExportRangeX on ExportRange {
  String label(AppLocalizations l10n) {
    switch (this) {
      case ExportRange.all:
        return l10n.rangeAll;
      case ExportRange.day:
        return l10n.rangeDay;
      case ExportRange.week:
        return l10n.rangeWeek;
      case ExportRange.month:
        return l10n.rangeMonth;
    }
  }

  /// Lower time bound (epoch millis) for filtering, or null for "all".
  int? get cutoffMillis {
    final now = DateTime.now();
    switch (this) {
      case ExportRange.all:
        return null;
      case ExportRange.day:
        return now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      case ExportRange.week:
        return now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      case ExportRange.month:
        return now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    }
  }
}

/// Unified row for the export file: a captured third-party notification or a
/// user-created pin.
class _ExportItem {
  final int timeMillis;
  final String source;
  final String? title;
  final String? content;
  final String? note;
  _ExportItem({
    required this.timeMillis,
    required this.source,
    this.title,
    this.content,
    this.note,
  });
}

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

  void _showHistoryMenu(BuildContext tileContext, ThirdPartyNotification n) {
    final l10n = AppLocalizations.of(tileContext);
    final notifier = ref.read(thirdPartyProvider.notifier);
    final renderBox = tileContext.findRenderObject();
    if (renderBox is! RenderBox) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
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
          value: 'pin',
          onTap: () => _pin(n),
          child: ListTile(
            leading: const Icon(Icons.vertical_align_top),
            title: Text(l10n.pinAction),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          onTap: () {
            final text =
                [n.title, n.content, n.note].whereType<String>().join('\n');
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

  Future<void> _pin(ThirdPartyNotification n) async {
    final l10n = AppLocalizations.of(context);

    // 通知可能只有内容没有标题；按「标题 → App 名 → 包名」兜底取值。
    final title =
        (n.title?.isNotEmpty == true) ? n.title! : (n.appName ?? n.packageName);
    final rawContent = n.content;
    final content = rawContent?.isNotEmpty == true ? rawContent : null;

    // 去重：同一条通知没必要反复钉成多个 Pin。
    final existing = await AppDatabase.notifications();
    if (existing.any((p) => p.equalsTitleAndContent(title, content))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.alreadyPinned)),
        );
      }
      return;
    }

    // Android 13+ 需要通知权限才能发常驻通知。
    final granted = await NotificationService.instance.requestPermission();
    if (granted == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.needNotificationPermission),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final pin = PinnitNotification(
      title: title,
      content: content,
      isPinned: true,
    );

    try {
      await ref.read(notificationsProvider.notifier).save(pin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveFailed(e.toString()))),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pinned)),
      );
    }
  }

  /// Opens the export sheet: pick a time range, then either save to local
  /// Downloads or share via the system sheet.
  void _openExportSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        var range = ExportRange.all;
        return StatefulBuilder(
          builder: (ctx, setSt) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.exportHistory,
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(l10n.exportRangeHint,
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ExportRange.values
                      .map(
                        (r) => ChoiceChip(
                          label: Text(r.label(l10n)),
                          selected: range == r,
                          onSelected: (_) => setSt(() => range = r),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: Text(l10n.saveToLocal),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _exportHistory(range, share: false);
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.ios_share),
                  label: Text(l10n.shareExport),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _exportHistory(range, share: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportHistory(ExportRange range, {required bool share}) async {
    final l10n = AppLocalizations.of(context);

    // 原始第三方通知历史 + 用户自己在「顶顶」里新建 / 顶出来的通知，合并导出。
    final thirdParty = await AppDatabase.thirdPartyNotifications();
    final ownPins = await AppDatabase.notifications();

    final cutoff = range.cutoffMillis;

    // 已导出的第三方「标题||内容」指纹，用于给自建通知去重
    // （被「顶」过的第三方通知会同时出现在两份记录里，避免重复列出）。
    final seen = <String>{};
    final items = <_ExportItem>[];

    for (final n in thirdParty) {
      if (cutoff != null && n.postedAt < cutoff) continue;
      final fp = '${n.title ?? ''}||${n.content ?? ''}';
      seen.add(fp);
      items.add(_ExportItem(
        timeMillis: n.postedAt,
        source: (n.appName?.isNotEmpty == true) ? n.appName! : n.packageName,
        title: n.title,
        content: n.content,
        note: n.note,
      ));
    }

    for (final p in ownPins) {
      final t = p.createdAt.millisecondsSinceEpoch;
      if (cutoff != null && t < cutoff) continue;
      final fp = '${p.title}||${p.content ?? ''}';
      if (seen.contains(fp)) continue; // 去重：避免和原始第三方通知重复
      items.add(_ExportItem(
        timeMillis: t,
        source: l10n.ownPinLabel,
        title: p.title,
        content: p.content,
        note: null,
      ));
    }

    // 排序：时间倒序（最新的在最上面）。
    items.sort((a, b) => b.timeMillis.compareTo(a.timeMillis));

    // 空判断：完全没数据 vs 该时间范围没数据，提示文案不同。
    final totalAll = thirdParty.length + ownPins.length;
    if (totalAll == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.historyEmptyExport)),
        );
      }
      return;
    }
    if (items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportEmptyRange)),
        );
      }
      return;
    }

    try {
      final now = DateTime.now();
      final timeFmt = DateFormat('yyyy-MM-dd HH:mm');
      final buffer = StringBuffer();
      buffer
        ..writeln('顶顶 通知历史导出')
        ..writeln('导出时间：${timeFmt.format(now)}')
        ..writeln('范围：${range.label(l10n)}')
        ..writeln('共 ${items.length} 条')
        ..writeln();
      const divider = '────────────────────────────────────────';
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        buffer
          ..writeln(divider)
          ..writeln('${i + 1}. ${it.source}')
          ..writeln('   时间：${timeFmt.format(
            DateTime.fromMillisecondsSinceEpoch(it.timeMillis),
          )}');
        if (it.title?.isNotEmpty == true) {
          buffer.writeln('   标题：${it.title}');
        }
        if (it.content?.isNotEmpty == true) {
          buffer.writeln('   内容：${it.content}');
        }
        if (it.note?.isNotEmpty == true) {
          buffer.writeln('   备注：${it.note}');
        }
      }
      buffer.writeln(divider);

      final dir = await getTemporaryDirectory();
      final exportDir = Directory('${dir.path}/export');
      await exportDir.create(recursive: true);
      final ts = DateFormat('yyyyMMdd_HHmm').format(now);
      final file = File('${exportDir.path}/pinnit_history_$ts.txt');
      await file.writeAsString(buffer.toString());

      if (share) {
        await NotificationListenerBridge.instance.shareFile(
          file.path,
          l10n.exportHistoryTitle,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.exportReady)),
          );
        }
      } else {
        final ok = await NotificationListenerBridge.instance.saveFileToDownloads(
          file.path,
          'pinnit_history_$ts.txt',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok
                  ? l10n.exportSavedLocal
                  : l10n.exportFailed('保存到本地失败')),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
        );
      }
    }
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
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l10n.exportHistory,
            onPressed: _openExportSheet,
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
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                        child: Builder(
                          builder: (tileCtx) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _editNote(n),
                            onLongPress: () => _showHistoryMenu(tileCtx, n),
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              child: ListTile(
                                leading: CircleAvatar(
                                child: Text(
                                  (n.appName ?? n.packageName).isNotEmpty
                                      ? (n.appName ?? n.packageName)[0]
                                          .toUpperCase()
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
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                            ),
                          ),
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
              searching ? l10n.tryAnotherKeyword : l10n.historyEmptyHint,
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

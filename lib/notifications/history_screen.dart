import 'dart:async';
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
import 'package:pinnit_flutter/settings/blocklist_screen.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';
import 'package:pinnit_flutter/theme/motion.dart';
import 'package:pinnit_flutter/widgets/app_animated_list.dart';
import 'package:pinnit_flutter/widgets/app_dialog.dart';
import 'package:pinnit_flutter/widgets/app_menu.dart';
import 'package:pinnit_flutter/widgets/app_page_route.dart';
import 'package:pinnit_flutter/widgets/glass_card.dart';
import 'package:pinnit_flutter/widgets/undo_toast.dart';

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
  final _scrollController = ScrollController();
  bool _searching = false;
  bool _listenerEnabled = false;

  /// The history row whose swipe-delete can still be undone. Non-null while
  /// the undo banner is on screen.
  ThirdPartyNotification? _undoNotif;

  /// Search used to filter the whole in-memory list on every keystroke. Now
  /// each keystroke only schedules one SQL query, debounced.
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Show the undo banner (and park the FAB while it is up, same corner).
  void _showUndo(ThirdPartyNotification n) {
    setState(() => _undoNotif = n);
    ref.read(undoBannerVisibleProvider.notifier).state = true;
  }

  /// Hide the banner. Every exit path (timeout / undo tap) funnels through
  /// here so the FAB always comes back.
  void _hideUndo() {
    if (_undoNotif == null) return;
    setState(() => _undoNotif = null);
    ref.read(undoBannerVisibleProvider.notifier).state = false;
  }

  /// Drop the banner once its countdown ran out — the delete stands.
  void _dismissUndo(String uuid) {
    if (_undoNotif?.uuid != uuid) return;
    _hideUndo();
  }

  /// Put the history row back and close the banner.
  void _undoDelete(ThirdPartyNotification n) {
    if (_undoNotif?.uuid != n.uuid) return;
    _hideUndo();
    ref.read(thirdPartyProvider.notifier).restore(n);
  }

  /// Bottom-of-screen undo bar. Rendered inside the body [Stack] instead of
  /// via `ScaffoldMessenger`, because a SnackBar carrying an action never
  /// auto-dismisses on this Flutter version (it defaults to `persist: true`).
  Widget _buildUndoBanner(AppLocalizations l10n) {
    final n = _undoNotif;
    return AnimatedSwitcher(
      duration: AppMotion.bannerIn,
      // 退出比进入快一档（20%）。进出都用同一条 ease-out 曲线，避免出现
      // 「进来是甩进来的、出去是慢慢拖走的」这种割裂感。
      reverseDuration: AppMotion.bannerOut,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.enter,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: n == null
          ? const SizedBox.shrink(key: ValueKey('undo-none'))
          : UndoToast(
              key: ValueKey('undo-${n.uuid}'),
              message: l10n.deleteUndo,
              undoLabel: l10n.undo,
              onUndo: () => _undoDelete(n),
              onDismissed: () => _dismissUndo(n.uuid),
            ),
    );
  }

  /// Load the next page when the user gets near the bottom.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.extentAfter < 600) {
      final s = ref.read(thirdPartyProvider);
      // Skip the round-trip when nothing useful can happen: no more pages,
      // a page is already in flight, or the user is searching (search mode
      // is a single server-side query, no paging).
      if (!s.hasMore || s.loading || s.query.isNotEmpty) return;
      ref.read(thirdPartyProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(thirdPartyProvider.notifier).setQuery(value);
    });
    // Reflect the typed text immediately so the field never feels laggy;
    // the results land when the debounced query resolves.
    setState(() {});
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
      await AppDialog.show<bool>(
        context: context,
        icon: Icons.info_outline,
        title: l10n.cannotOpenSettings,
        message: l10n.manualSettingsGuide,
        actions: [
          AppDialogAction<bool>(
            label: l10n.gotIt,
            style: AppDialogActionStyle.primary,
          ),
        ],
      );
      return;
    }
    // 设置是另一个应用；稍等片刻再重新检查授权状态。
    await Future.delayed(const Duration(seconds: 1));
    await _checkPermission();
  }

  Future<void> _editNote(ThirdPartyNotification n) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: n.note ?? '');
    final result = await AppDialog.show<String>(
      context: context,
      icon: Icons.notes,
      title: l10n.addNote,
      content: AppDialog.filledField(
        context: context,
        controller: controller,
        hint: l10n.noteHint,
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        AppDialogAction<String>(label: l10n.cancel),
        AppDialogAction<String>(
          label: l10n.save,
          style: AppDialogActionStyle.primary,
          // 必须在这里取值：写 value: 会在弹窗构建时就把旧文本固化下来。
          valueBuilder: () => controller.text.trim(),
        ),
      ],
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
    // 走 AppMenu 的快速菜单（150ms 淡入 + 缩放），和自建页同一套手感。
    AppMenu.show(
      context: tileContext,
      items: [
        AppMenuEntry(
          icon: Icons.vertical_align_top,
          label: l10n.pinAction,
          onTap: () => _pin(n),
        ),
        AppMenuEntry(
          icon: Icons.copy,
          label: l10n.copy,
          onTap: () {
            final text =
                [n.title, n.content, n.note].whereType<String>().join('\n');
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.copiedToClipboard)),
            );
          },
        ),
        AppMenuEntry(
          icon: Icons.delete_outline,
          label: l10n.delete,
          isDanger: true,
          onTap: () => notifier.delete(n.uuid),
        ),
      ],
    );
  }

  /// 历史页用的是裸 GestureDetector，它不像 InkWell/ListTile 那样自带长按震动，
  /// 所以这里手动补上系统触觉反馈，两页手感才一致。
  void _onLongPressRow(BuildContext tileContext, ThirdPartyNotification n) {
    Feedback.forLongPress(tileContext);
    _showHistoryMenu(tileContext, n);
  }

  Future<void> _pin(ThirdPartyNotification n) async {
    final l10n = AppLocalizations.of(context);

    // 通知可能只有内容没有标题；按「标题 → App 名 → 包名」兜底取值。
    final title =
        (n.title?.isNotEmpty == true) ? n.title! : (n.appName ?? n.packageName);
    final rawContent = n.content;
    final content = rawContent?.isNotEmpty == true ? rawContent : null;

    // 去重：同一条通知没必要反复钉成多个 Pin。
    // 直接读内存里的状态，避免再打一次数据库。
    final existing = ref.read(notificationsProvider);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? const Color(0xFF231F1B) : const Color(0xFFF5EFE6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        var range = ExportRange.all;
        return StatefulBuilder(
          builder: (ctx, setSt) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.exportHistory,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                Text(l10n.exportRangeHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                _buildRangeSelector(
                  ctx,
                  range,
                  (r) => setSt(() => range = r),
                  l10n,
                ),
                const SizedBox(height: 18),
                _buildActionCard(
                  ctx,
                  icon: Icons.download_outlined,
                  title: l10n.saveToLocal,
                  subtitle: l10n.exportSaveHint,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _exportHistory(range, share: false);
                  },
                ),
                const SizedBox(height: 10),
                _buildActionCard(
                  ctx,
                  icon: Icons.ios_share,
                  title: l10n.shareExport,
                  subtitle: l10n.exportShareHint,
                  onTap: () {
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

  /// 四个时间范围合并成一个整体的分段控件。
  ///
  /// 原来是四个各自独立的 ChoiceChip，看不出「四选一」这层关系；合成一体后
  /// 视觉更安静，也更贴近系统级的控件质感。
  Widget _buildRangeSelector(
    BuildContext ctx,
    ExportRange current,
    ValueChanged<ExportRange> onPick,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(ctx);
    final isDark = theme.brightness == Brightness.dark;
    final track =
        isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFEDE3D2);
    final idleFg = isDark ? const Color(0xFFC9B99A) : const Color(0xFF6B5B45);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: ExportRange.values.map((r) {
          final selected = r == current;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  r.label(l10n),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w500 : FontWeight.w400,
                    color: selected ? theme.colorScheme.onPrimary : idleFg,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 一行带说明文字的导出操作卡。
  ///
  /// 换成卡片行之后，每个操作能多交代一句「存到哪儿 / 发到哪儿」，
  /// 比两个光秃秃的大按钮信息量更足。
  Widget _buildActionCard(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(ctx);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF2E2823) : const Color(0xFFFDFBF7);
    final border =
        isDark ? Colors.white.withOpacity(0.10) : const Color(0xFFF2EADC);
    final textColor = isDark ? const Color(0xFFEDE4D3) : const Color(0xFF3B3226);
    final muted = isDark ? Colors.white54 : const Color(0xFFA39A89);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportHistory(ExportRange range, {required bool share}) async {
    final l10n = AppLocalizations.of(context);

    // 原始第三方通知历史 + 用户自己在「顶顶」里新建 / 顶出来的通知，合并导出。
    // 导出要全量，所以显式把分页上限拉到最大（列表界面用的是分页默认值）。
    final thirdParty =
        await AppDatabase.thirdPartyNotifications(limit: 1 << 30);
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
        ..writeln(l10n.exportHeader)
        ..writeln('${l10n.exportTimeLabel}: ${timeFmt.format(now)}')
        ..writeln('${l10n.exportRangeLabel}: ${range.label(l10n)}')
        ..writeln(l10n.exportCountLabel(items.length))
        ..writeln();
      const divider = '────────────────────────────────────────';
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        buffer
          ..writeln(divider)
          ..writeln('${i + 1}. ${it.source}')
          ..writeln('   ${l10n.exportItemTimeLabel}: ${timeFmt.format(
            DateTime.fromMillisecondsSinceEpoch(it.timeMillis),
          )}');
        if (it.title?.isNotEmpty == true) {
          buffer.writeln('   ${l10n.exportItemTitleLabel}: ${it.title}');
        }
        if (it.content?.isNotEmpty == true) {
          buffer.writeln('   ${l10n.exportItemContentLabel}: ${it.content}');
        }
        if (it.note?.isNotEmpty == true) {
          buffer.writeln('   ${l10n.exportItemNoteLabel}: ${it.note}');
        }
      }
      buffer.writeln(divider);

      final dir = await getTemporaryDirectory();
      final exportDir = Directory('${dir.path}/export');
      await exportDir.create(recursive: true);
      final ts = DateFormat('yyyyMMdd_HHmm').format(now);
      final file = File('${exportDir.path}/dingpin_history_$ts.txt');
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
    final historyState = ref.watch(thirdPartyProvider);
    final notifier = ref.read(thirdPartyProvider.notifier);
    // Filtering now happens in SQL (debounced), so the list is shown as-is.
    final visible = historyState.items;
    final theme = Theme.of(context);

    return Scaffold(
      // Transparent so MainScreen's gradient backing + glass bottom nav
      // can read the body underneath.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        // 与首页一致：透明顶栏 + 不随滚动变暗，暖金背景直接透上来。
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchHistoryHint,
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : Text(l10n.historyTitle),
        actions: [
          if (!_searching)
            IconButton(
              icon: Icon(historyState.groupByApp
                  ? Icons.view_list
                  : Icons.apps_outlined),
              tooltip: l10n.groupByApp,
              onPressed: () =>
                  ref.read(thirdPartyProvider.notifier).toggleGroupByApp(),
            ),
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchController.clear();
                  _searchDebounce?.cancel();
                  ref.read(thirdPartyProvider.notifier).setQuery('');
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l10n.exportHistory,
            onPressed: _openExportSheet,
          ),
          if (!_searching)
            PopupMenuButton<String>(
              color: AppMenu.surface(context),
              shape: AppMenu.shape(context),
              elevation: 8,
              onSelected: (value) {
                if (value == 'clear') {
                  AppDialog.show<bool>(
                    context: context,
                    icon: Icons.delete_sweep_outlined,
                    isDestructive: true,
                    title: l10n.clearHistoryTitle,
                    message: l10n.clearHistoryBody,
                    actions: [
                      AppDialogAction<bool>(label: l10n.cancel),
                      AppDialogAction<bool>(
                        label: l10n.clearAll,
                        style: AppDialogActionStyle.danger,
                        onPressed: () => notifier.clearAll(),
                      ),
                    ],
                  );
                } else if (value == 'blocklist') {
                  Navigator.of(context).push(AppPageRoute(
                    builder: (_) => const BlocklistScreen(),
                  ));
                }
              },
              itemBuilder: (ctx) => [
                AppMenu.item(
                  value: 'blocklist',
                  icon: Icons.block,
                  label: l10n.blocklist,
                ),
                AppMenu.divider(context),
                AppMenu.item(
                  value: 'clear',
                  icon: Icons.delete_sweep_outlined,
                  label: l10n.clearAllMenu,
                ),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
        children: [
          if (!_listenerEnabled)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.error.withOpacity(0.35),
                  width: 1,
                ),
              ),
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
                ? _EmptyState(
                    searching:
                        _searching || _searchController.text.isNotEmpty)
                : historyState.groupByApp
                    ? _buildGroupedView(visible, theme, l10n, notifier)
                    : _buildFlatView(
                        visible, historyState, theme, l10n, notifier),
          ),
        ],
            ),
          ),
          // Floating above the glass tab bar (72 + 14 margin).
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: _buildUndoBanner(l10n),
          ),
        ],
      ),
    );
  }

  /// Flat (non-grouped) list with paging + swipe-to-delete.
  ///
  /// 用 [AppAnimatedList] 而不是 `ListView.separated`：删一条时那张卡片要
  /// 「收起来」，下面的内容平滑地补上空位，而不是整屏往上跳一格。
  Widget _buildFlatView(
    List<ThirdPartyNotification> visible,
    HistoryState historyState,
    ThemeData theme,
    AppLocalizations l10n,
    ThirdPartyNotifier notifier,
  ) {
    // 分页的 loading 指示不再挂在列表最后一格（AnimatedList 的条目数由它自己
    // 持有，塞不进去），改成钉在列表底部。
    return Column(
      children: [
        Expanded(
          child: AppAnimatedList<ThirdPartyNotification>(
            items: visible,
            idOf: (n) => n.uuid,
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 140),
            itemBuilder: (context, n) => Dismissible(
              key: ValueKey(n.uuid),
              direction: DismissDirection.endToStart,
              // 防误触：默认 0.4 阈值太敏感，提到 0.6（要滑过 60% 才触发）
              dismissThresholds: const {
                DismissDirection.endToStart: 0.6,
              },
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                // 5 秒读秒横幅代替 SnackBar：带 action 的 SnackBar 在本
                // Flutter 版本默认 persist: true，永不自动消失（旧 bug 根因）。
                await notifier.delete(n.uuid);
                if (!context.mounted) return false;
                _showUndo(n);
                // 返回 false：数据已经删了，收起过渡交给列表，别让
                // Dismissible 在原地回弹（离场副本不带手势）。
                return false;
              },
              child: _buildCard(n, theme, l10n),
            ),
            // 离场版本：同一张卡，去掉滑动手势。
            removedItemBuilder: (context, n) =>
                _buildCard(n, theme, l10n, interactive: false),
          ),
        ),
        // "load more" 指示：只在一轮分页真的在途中出现。
        if (historyState.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  /// Group the visible items by app name (or package name as fallback).
  ///
  /// Each app is an [ExpansionTile] showing the count; tapping expands to
  /// reveal the individual notifications. The first group is expanded by
  /// default so the user sees the most recent app's notifications without an
  /// extra tap.
  Widget _buildGroupedView(
    List<ThirdPartyNotification> items,
    ThemeData theme,
    AppLocalizations l10n,
    ThirdPartyNotifier notifier,
  ) {
    // Group by appName ?? packageName, falling back to '?' for empties.
    final groups = <String, List<ThirdPartyNotification>>{};
    for (final n in items) {
      final key = (n.appName ?? n.packageName).isNotEmpty
          ? (n.appName ?? n.packageName)
          : '?';
      groups.putIfAbsent(key, () => []).add(n);
    }

    // Sort groups by the newest notification in each (DESC).
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) =>
          groups[b]!.first.postedAt.compareTo(groups[a]!.first.postedAt));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: sortedKeys.length,
      itemBuilder: (context, i) {
        final key = sortedKeys[i];
        final group = groups[key]!;
        // Group container: one big glass card wraps the whole app group.
        // Inside, header row + compact item rows form a two-level
        // "container → rows" hierarchy instead of card-on-card.
        return Padding(
          // Breathing room between collapsed group cards.
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Theme(
              // Kill ExpansionTile's default divider (the black hairline).
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: i == 0,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const Border(),
                collapsedShape: const Border(),
                iconColor: theme.colorScheme.primary,
                collapsedIconColor: theme.colorScheme.onSurfaceVariant,
                title: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          theme.colorScheme.primaryContainer,
                      foregroundColor:
                          theme.colorScheme.onPrimaryContainer,
                      child: Text(
                        key[0].toUpperCase(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      l10n.groupedAppCount(group.length),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                subtitle: Text(
                  _formatTime(group.first.postedAt, l10n),
                  style: theme.textTheme.bodySmall,
                ),
                children: [
                  for (final n in group)
                    _buildGroupRow(n, theme, l10n),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  /// A compact row INSIDE a group card — visually lighter than the old
  /// per-notification GlassCard: transparent fill, no per-row
  /// border/shadow. The outer card provides the glass surface; rows just
  /// separate content.
  Widget _buildGroupRow(
    ThirdPartyNotification n,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final subtle = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.04)
        : Colors.white.withOpacity(0.45);
    return Builder(
      builder: (tileCtx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _editNote(n),
        onLongPress: () => _onLongPressRow(tileCtx, n),
        child: Container(
          color: subtle,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title?.isNotEmpty == true
                          ? n.title!
                          : (n.appName ?? n.packageName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (n.content?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        n.content!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(n.postedAt, l10n),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A single notification card. Shared between flat and grouped views so
  /// they look identical. Tap edits the note; long-press opens the action
  /// menu (pin / copy / delete).
  /// 一张历史卡。
  ///
  /// [interactive] = false 是**正在离场的副本**：这行数据已经删了，只等收起
  /// 动画播完，此时不该再响应点击和长按菜单。
  Widget _buildCard(
    ThirdPartyNotification n,
    ThemeData theme,
    AppLocalizations l10n, {
    bool interactive = true,
  }) {
    return Builder(
      builder: (tileCtx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? () => _editNote(n) : null,
        onLongPress:
            interactive ? () => _onLongPressRow(tileCtx, n) : null,
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                (n.appName ?? n.packageName).isNotEmpty
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
          ),
        ),
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
                color: theme.colorScheme.primary.withOpacity(0.6)),
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

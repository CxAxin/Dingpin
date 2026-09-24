import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/editor/editor_screen.dart';
import 'package:pinnit_flutter/providers.dart';
import 'package:pinnit_flutter/repositories/notifications_repository.dart';
import 'package:pinnit_flutter/notifications/notification_tile.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';
import 'package:pinnit_flutter/theme/motion.dart';
import 'package:pinnit_flutter/widgets/app_animated_list.dart';
import 'package:pinnit_flutter/widgets/app_page_route.dart';
import 'package:pinnit_flutter/widgets/glass_card.dart';
import 'package:pinnit_flutter/widgets/undo_toast.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  /// The notification whose swipe-delete can still be undone. Non-null while
  /// the undo banner is on screen.
  PinnitNotification? _undoNotif;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Show the undo banner, and give the FAB a heads-up so it can step aside
  /// (the banner floats in the same corner it does).
  void _showUndo(PinnitNotification n) {
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

  /// Put the notification back and close the banner.
  void _undoDelete(PinnitNotification n) {
    if (_undoNotif?.uuid != n.uuid) return;
    _hideUndo();
    ref.read(notificationsProvider.notifier).restore(n);
  }

  /// Bottom-of-screen undo bar. Rendered inside the body [Stack] instead of
  /// via `ScaffoldMessenger`, because a SnackBar carrying an action never
  /// auto-dismisses on this Flutter version.
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

  /// 一张通知卡。
  ///
  /// [interactive] = false 用在**正在离场的副本**上：这一行已经被删除了，只是
  /// 还在播收起过渡。这时候必须去掉点击和长按菜单——一来用户点它没意义，
  /// 二来套在上面的 Dismissible 会在原地回弹，跟收起动画打架。
  Widget _buildCard(
    BuildContext context,
    PinnitNotification n,
    NotificationsNotifier notifier,
    AppLocalizations l10n, {
    bool interactive = true,
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: NotificationTile(
        notification: n,
        onTap: !interactive
            ? null
            : () => Navigator.of(context).push(
                  AppPageRoute(
                    builder: (_) => EditorScreen(uuid: n.uuid),
                  ),
                ),
        onTogglePin: !interactive ? null : () => notifier.togglePin(n),
        onDelete: !interactive ? null : () => notifier.delete(n),
        onCopy: !interactive
            ? null
            : () {
                final text = [n.title, n.content]
                    .whereType<String>()
                    .join('\n');
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.copiedWithText(text)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
        interactive: interactive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notifications = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    final visible = _filter(notifications, _searchController.text);

    return Scaffold(
      // Transparent so MainScreen's gradient backing + glass bottom nav
      // can read the body underneath.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchNotificationsHint,
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(l10n.appTitle),
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
            tooltip: l10n.toggleTheme,
            onPressed: () {
              final mode = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).state =
                  mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: visible.isEmpty
                ? _EmptyState(searching: _searching)
                : AppAnimatedList<PinnitNotification>(
              items: visible,
              idOf: (n) => n.uuid,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 140),
              itemBuilder: (context, n) => Dismissible(
                key: ValueKey(n.uuid),
                direction: DismissDirection.endToStart,
                // 防误触：默认 dismiss 阈值 0.4 太敏感，手指稍微侧
                // 滑就触发删除。提到 0.6（要滑过 60% 卡片宽度才生效）。
                dismissThresholds: const {
                  DismissDirection.endToStart: 0.6,
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  // 不弹确认对话框，改为在底部弹 5 秒读秒横幅给后悔机会。
                  // 注意：这里不能用 SnackBar——本 Flutter 版本中带 action 的
                  // SnackBar 默认 persist: true，永不自动消失（旧 bug 根因）。
                  await notifier.delete(n);
                  if (!context.mounted) return false;
                  _showUndo(n);
                  // 返回 false 让 Dismissible 不再接管这次删除：数据已经改了，
                  // 收起过渡由 AppAnimatedList 负责（它会把这一行换成"没有手势
                  // 的版本"再收起，所以不会看到 Dismissible 回弹）。
                  return false;
                },
                child: _buildCard(context, n, notifier, l10n),
              ),
              // 离场版本：同一张卡，去掉滑动手势。
              removedItemBuilder: (context, n) =>
                  _buildCard(context, n, notifier, l10n, interactive: false),
            ),
          ),
          // Floating above the glass tab bar (72 + 14 margin) so the
          // countdown ring stays fully visible.
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
            Icon(Icons.push_pin_outlined,
                size: 64, color: theme.colorScheme.primary.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              searching ? l10n.noMatch : l10n.noNotifications,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? l10n.tryAnotherKeyword
                  : l10n.emptyPinHint,
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

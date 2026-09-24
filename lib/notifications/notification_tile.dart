import 'package:flutter/material.dart';

import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';
import 'package:pinnit_flutter/widgets/app_menu.dart';

/// A single row in the notification list showing the title, optional content,
/// and a pin toggle that mirrors Pinnit's "pinned first" ordering.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onTogglePin,
    this.onDelete,
    this.onCopy,
    this.interactive = true,
  });

  final PinnitNotification notification;

  /// 四个回调都可以留空：正在离场的那一行（见 AppAnimatedList 的
  /// removedItemBuilder）不该再响应点击和长按。
  final VoidCallback? onTap;
  final VoidCallback? onTogglePin;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;

  /// `false` 时这一行纯粹是张"画"，不带任何交互——用于正在收起的离场副本。
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      // 长按菜单的震动由 ListTile 内部的 InkWell 自动触发，不用再调一次。
      onLongPress: interactive ? () => _showContextMenu(context) : null,
      leading: IconButton(
        tooltip: notification.isPinned ? l10n.unpinAction : l10n.pinAction,
        icon: Icon(
          notification.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          color: notification.isPinned ? theme.colorScheme.primary : null,
        ),
        onPressed: onTogglePin,
      ),
      title: Text(
        notification.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: notification.content != null
          ? Text(
              notification.content!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: null,
    );
  }

  void _showContextMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 走 AppMenu 的快速菜单（150ms 淡入 + 缩放），与历史页同一套外观和手感。
    // 震动由 ListTile 内部的 InkWell 自动触发，这里不用再调一次。
    AppMenu.show(
      context: context,
      items: [
        AppMenuEntry(
          icon: notification.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
          label: notification.isPinned ? l10n.unpinAction : l10n.pinAction,
          onTap: onTogglePin,
        ),
        AppMenuEntry(
          icon: Icons.copy_outlined,
          label: l10n.copy,
          // 复制这件事统一在调用方做（含 SnackBar 提示）。这里再写一份会
          // 写两次剪贴板。
          onTap: onCopy,
        ),
        AppMenuEntry(
          icon: Icons.delete_outline,
          label: l10n.delete,
          isDanger: true,
          onTap: onDelete,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';

/// A single row in the notification list showing the title, optional content,
/// and a pin toggle that mirrors Pinnit's "pinned first" ordering.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
    required this.onCopy,
  });

  final PinnitNotification notification;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
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
            onCopy();
            final text = [notification.title, notification.content]
                .whereType<String>()
                .join('\n');
            Clipboard.setData(ClipboardData(text: text));
          },
          child: ListTile(
            leading: const Icon(Icons.copy),
            title: Text(l10n.copy),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'toggle_pin',
          onTap: onTogglePin,
          child: ListTile(
            leading: Icon(
              notification.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
            ),
            title: Text(notification.isPinned ? l10n.unpinAction : l10n.pinAction),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          onTap: onDelete,
          child: ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

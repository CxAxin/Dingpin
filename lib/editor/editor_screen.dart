import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pinnit_flutter/data/app_database.dart';
import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/repositories/notifications_repository.dart';
import 'package:pinnit_flutter/services/notification_service.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';

/// Create / edit screen. When [uuid] is null we are creating a new
/// notification, otherwise we load the existing one and edit it.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.uuid});

  final String? uuid;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isPinned = true;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.uuid == null) {
      setState(() => _loading = false);
      return;
    }
    final existing = await AppDatabase.notificationByUuid(widget.uuid!);
    if (existing != null) {
      _titleController.text = existing.title;
      _contentController.text = existing.content ?? '';
      _isPinned = existing.isPinned;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.titleEmpty)),
      );
      return;
    }

    // On Android 13+ the user must explicitly grant POST_NOTIFICATIONS before
    // we can show a pinned notification. We ask here so a denied permission
    // is surfaced immediately instead of silently failing.
    if (_isPinned) {
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
    }

    final n = PinnitNotification(
      uuid: widget.uuid,
      title: title,
      content: _contentController.text.trim().isEmpty
          ? null
          : _contentController.text.trim(),
      isPinned: _isPinned,
    );

    try {
      await ref.read(notificationsProvider.notifier).save(n);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveFailed(e.toString()))),
        );
      }
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.uuid == null ? l10n.newNotification : l10n.editNotification),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: l10n.titleLabel,
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            decoration: InputDecoration(
              labelText: l10n.contentLabel,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(l10n.pinToNotification),
            subtitle: Text(l10n.pinSubtitle),
            value: _isPinned,
            onChanged: (v) => setState(() => _isPinned = v),
          ),
        ],
      ),
    );
  }
}

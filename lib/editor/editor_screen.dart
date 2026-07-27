import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pinnit_flutter/data/app_database.dart';
import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/repositories/notifications_repository.dart';
import 'package:pinnit_flutter/services/notification_service.dart';

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
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题不能为空')),
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
          const SnackBar(
            content: Text('需要通知权限才能固定到通知栏，请去系统设置中开启'),
            duration: Duration(seconds: 4),
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
          SnackBar(content: Text('保存失败：$e')),
        );
      }
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.uuid == null ? '新建通知' : '编辑通知'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '标题',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(
              labelText: '内容（可选）',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('固定到通知栏'),
            subtitle: const Text('让它一直显示在通知栏中'),
            value: _isPinned,
            onChanged: (v) => setState(() => _isPinned = v),
          ),
        ],
      ),
    );
  }
}

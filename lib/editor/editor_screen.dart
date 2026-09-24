import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pinnit_flutter/data/app_database.dart';
import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/repositories/notifications_repository.dart';
import 'package:pinnit_flutter/services/notification_service.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';
import 'package:pinnit_flutter/widgets/aurora_backdrop.dart';
import 'package:pinnit_flutter/widgets/glass_card.dart';
import 'package:pinnit_flutter/widgets/warm_field.dart';

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

  /// Guards against double-taps and gives the user visible feedback while the
  /// write is in flight — previously a slow save just looked like a dead button.
  bool _saving = false;

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
    if (_saving) return;
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

    if (mounted) setState(() => _saving = true);
    try {
      await ref.read(notificationsProvider.notifier).save(n);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
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

    // 背景铺在 Scaffold 外层：AppBar 透明后直接透出暖金纸感，Scaffold 也会
    // 正常为 AppBar 让位，内容不必再手动让 kToolbarHeight（旧写法让了两遍，
    // 标题和第一张卡片之间会空出一整条工具栏）。
    return AuroraBackdrop(
      brightness: Theme.of(context).brightness,
      showBottomGlow: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            widget.uuid == null ? l10n.newNotification : l10n.editNotification,
          ),
        ),
        body: SafeArea(
          top: false, // AppBar 已让过状态栏
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              // 「内容」与「行为」分成两张玻璃卡，视觉上有分组、也更好扫。
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildField(
                      controller: _titleController,
                      hint: l10n.titleLabel,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _contentController,
                      hint: l10n.contentLabel,
                      maxLines: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: SwitchListTile(
                  title: Text(l10n.pinToNotification),
                  subtitle: Text(l10n.pinSubtitle),
                  value: _isPinned,
                  onChanged: (v) => setState(() => _isPinned = v),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          l10n.save,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 填充式输入框：样式统一在 [WarmField] 里（三处曾各抄一份）。
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
  }) {
    return WarmField(
      controller: controller,
      hint: hint,
      maxLines: maxLines,
    );
  }
}

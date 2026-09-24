// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'package:flutter/material.dart';

import 'package:pinnit_flutter/l10n/app_localizations.dart';
import 'package:pinnit_flutter/services/blocklist_service.dart';
import 'package:pinnit_flutter/widgets/aurora_backdrop.dart';
import 'package:pinnit_flutter/widgets/glass_card.dart';
import 'package:pinnit_flutter/widgets/warm_field.dart';

/// Manage the keyword blocklist for notification history.
///
/// Each line is a keyword. A captured notification whose title, content, or
/// app name *contains* any keyword (case-insensitive) is silently dropped
/// before it reaches the database or the UI.
///
/// This is the user's main tool for taming noisy status notifications like
/// "正在扫描周围设备" / "正在获取服务信息" that re-fire every few seconds.
class BlocklistScreen extends StatefulWidget {
  const BlocklistScreen({super.key});

  @override
  State<BlocklistScreen> createState() => _BlocklistScreenState();
}

class _BlocklistScreenState extends State<BlocklistScreen> {
  final _controller = TextEditingController();
  List<String> _words = [];
  int _blockedCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _words = BlocklistService.instance.words;
      _blockedCount = BlocklistService.instance.blockedCount;
    });
  }

  Future<void> _add() async {
    final word = _controller.text.trim();
    if (word.isEmpty) return;
    await BlocklistService.instance.add(word);
    _controller.clear();
    _refresh();
  }

  Future<void> _remove(String word) async {
    await BlocklistService.instance.remove(word);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final muted = isDark ? Colors.white54 : const Color(0xFF8C8172);

    return AuroraBackdrop(
      brightness: brightness,
      showBottomGlow: false,
      // 背景铺在 Scaffold *外面*：AppBar 透明后能直接透出暖金纸感，同时
      // Scaffold 会正常为 AppBar 让位 —— 内容不需要也不该再手动让高度
      // （旧写法让了两遍，标题和说明小字之间空出一整条工具栏）。
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(l10n.blocklistTitle),
        ),
        body: SafeArea(
          top: false, // AppBar 已经让过状态栏了
          child: Column(
            children: [
              // ── 说明 + 命中计数 ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.blocklistHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                        height: 1.5,
                      ),
                    ),
                    if (_blockedCount > 0) ...[
                      const SizedBox(height: 10),
                      _BlockedPill(
                        label: l10n.blockedCount(_blockedCount),
                      ),
                    ],
                  ],
                ),
              ),
              // ── 添加行 ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: WarmField(
                          controller: _controller,
                          hint: l10n.blocklistAddHint,
                          onSubmitted: (_) => _add(),
                          textCapitalization: TextCapitalization.none,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _add,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            l10n.blocklistAdd,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── 关键词列表 ─────────────────────────────────
              Expanded(
                child: _words.isEmpty
                    ? _buildEmpty(theme, l10n, isDark)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
                        itemCount: _words.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final word = _words[index];
                          return _WordRow(
                            word: word,
                            onRemove: () => _remove(word),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme, AppLocalizations l10n, bool isDark) {
    final accent = theme.colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: accent.withOpacity(isDark ? 0.16 : 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block,
                size: 36,
                color: accent.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.blocklistEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isDark ? const Color(0xFFEDE4D3) : const Color(0xFF3B3226),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 命中计数的小药丸（原来只是一行彩色小字，太容易被忽略）。
class _BlockedPill extends StatelessWidget {
  const _BlockedPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(isDark ? 0.18 : 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个关键词行：暖色玻璃条 + 圆角图标底 + 右侧移除按钮。
///
/// 原来是「ListTile + Divider」的表格形态，跟 App 其他页面的卡片语言不一致。
class _WordRow extends StatelessWidget {
  const _WordRow({required this.word, required this.onRemove});

  final String word;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface =
        isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFFDFBF7).withOpacity(0.72);
    final border = isDark
        ? Colors.white.withOpacity(0.11)
        : const Color(0xFFF7F1E4).withOpacity(0.95);
    final textColor = isDark ? const Color(0xFFEDE4D3) : const Color(0xFF3B3226);
    final muted = isDark ? Colors.white54 : const Color(0xFFA39A89);
    final accent = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withOpacity(isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.block, size: 17, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: textColor),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 19),
            color: muted,
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

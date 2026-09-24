import 'package:flutter/material.dart';

import 'package:pinnit_flutter/widgets/warm_field.dart';

/// 「顶顶」对话框的统一外观。
///
/// 系统默认的 `AlertDialog` 是 4px 小圆角 + 纯白底 + 右下角一排裸文字按钮，
/// 跟 App 的暖金玻璃卡风格不搭（和 `AppMenu` 遇到的是同一个问题）。这里把
/// 对话框收敛到同一套语言：24px 圆角、暖白玻璃底、顶部可选的暖色圆底图标、
/// 底部等宽的大圆角按钮（主操作实心暖金、破坏性操作实心红、次要操作浅填充）。
///
/// 用法：
/// ```dart
/// final ok = await AppDialog.show<bool>(
///   context: context,
///   icon: Icons.delete_sweep_outlined,
///   isDestructive: true,
///   title: l10n.clearHistoryTitle,
///   message: l10n.clearHistoryBody,
///   actions: [
///     AppDialogAction(label: l10n.cancel),
///     AppDialogAction(
///       label: l10n.clearAll,
///       style: AppDialogActionStyle.danger,
///       onPressed: () => notifier.clearAll(),
///     ),
///   ],
/// );
/// ```
class AppDialog {
  const AppDialog._();

  static const double radius = 24;
  static const double actionRadius = 14;
  static const double actionHeight = 46;

  /// 破坏性操作（清空、删除）统一用这个红，和 `AppMenu.danger` 保持一致。
  static const Color danger = Color(0xFFB3261E);

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    IconData? icon,
    Widget? content,
    required List<AppDialogAction<T>> actions,
    bool isDestructive = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => _AppDialogView<T>(
        title: title,
        message: message,
        icon: icon,
        content: content,
        actions: actions,
        isDestructive: isDestructive,
      ),
    );
  }

  /// 暖色填充式输入框。样式统一在 [WarmField] 里，这里只是留一个语义化的
  /// 入口，方便对话框场景阅读。
  static Widget filledField({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool autofocus = false,
  }) {
    return WarmField(
      controller: controller,
      hint: hint,
      maxLines: maxLines,
      autofocus: autofocus,
    );
  }
}

/// 对话框底部的一个按钮。
///
/// `onPressed` 如果给了，会在弹窗关闭之后执行（原来的代码也是先 pop 再干活），
/// 这样在回调里引用页面级 notifier 是安全的。
class AppDialogAction<T> {
  const AppDialogAction({
    required this.label,
    this.value,
    this.valueBuilder,
    this.onPressed,
    this.style = AppDialogActionStyle.secondary,
  });

  final String label;

  /// 关闭弹窗时返回的值。
  final T? value;

  /// 需要在「点击那一刻」才取值时用这个（例如返回输入框里的当前文本）。
  /// ⚠️ 别用 `value:` 传 `controller.text` —— 那会在弹窗构建时就固化成旧值。
  final ValueGetter<T?>? valueBuilder;

  /// 关闭之后要执行的动作。
  final VoidCallback? onPressed;

  final AppDialogActionStyle style;
}

enum AppDialogActionStyle { secondary, primary, danger }

class _AppDialogView<T> extends StatelessWidget {
  const _AppDialogView({
    this.title,
    this.message,
    this.icon,
    this.content,
    required this.actions,
    this.isDestructive = false,
  });

  final String? title;
  final String? message;
  final IconData? icon;
  final Widget? content;
  final List<AppDialogAction<T>> actions;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF231F1B) : const Color(0xFFFDFBF7);
    final border = isDark ? Colors.white.withOpacity(0.10) : const Color(0xFFEADFC8);
    final textColor = isDark ? const Color(0xFFEDE4D3) : const Color(0xFF3B3226);
    final muted = isDark ? Colors.white54 : const Color(0xFF8C8172);
    final accent = isDestructive ? AppDialog.danger : theme.colorScheme.primary;

    // 先取到局部变量：字段是 public 的，Dart 不会对它做 null 提升。
    final titleText = title;
    final messageText = message;
    final body = content;
    final hasHeader = icon != null || titleText != null || messageText != null;

    return Dialog(
      backgroundColor: surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDialog.radius),
        side: BorderSide(color: border, width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 21, color: accent),
              ),
              const SizedBox(height: 15),
            ],
            if (titleText != null)
              Text(
                titleText,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.25,
                ),
              ),
            if (messageText != null) ...[
              SizedBox(height: titleText == null ? 0 : 8),
              Text(
                messageText,
                style: TextStyle(fontSize: 14, color: muted, height: 1.5),
              ),
            ],
            if (body != null) ...[
              SizedBox(height: hasHeader ? 16 : 0),
              // 撑满宽度：Column 给子项的是 loose 约束，TextField 这类
              // 需要「有界宽度」的控件拿不到确定宽度会渲染异常。
              SizedBox(width: double.infinity, child: body),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 22),
              _buildActions(context, theme, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, ThemeData theme, bool isDark) {
    final buttons = actions
        .map((a) => _buildActionButton(context, a, theme, isDark))
        .toList();

    // 单个按钮占满整行；两个及以上等分排列。
    if (buttons.length == 1) {
      return SizedBox(width: double.infinity, child: buttons.first);
    }
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    AppDialogAction<T> action,
    ThemeData theme,
    bool isDark,
  ) {
    Color bg;
    Color fg;
    switch (action.style) {
      case AppDialogActionStyle.primary:
        bg = theme.colorScheme.primary;
        fg = theme.colorScheme.onPrimary;
        break;
      case AppDialogActionStyle.danger:
        bg = AppDialog.danger;
        fg = Colors.white;
        break;
      case AppDialogActionStyle.secondary:
        bg = isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFF2EADC);
        fg = isDark ? const Color(0xFFE0D6C4) : const Color(0xFF6B5B45);
        break;
    }

    return SizedBox(
      height: AppDialog.actionHeight,
      child: TextButton(
        onPressed: () {
          Navigator.of(context)
              .pop(action.valueBuilder?.call() ?? action.value);
          action.onPressed?.call();
        },
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDialog.actionRadius),
          ),
        ),
        child: FittedBox(
          child: Text(action.label, maxLines: 1),
        ),
      ),
    );
  }
}

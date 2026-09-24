import 'package:flutter/material.dart';

/// 暖色填充式输入框 —— 全站唯一的输入框外观。
///
/// 去掉系统默认的描边方框（`OutlineInputBorder`），改成暖色圆角底；
/// 只有聚焦时才浮出一圈暖金描边，避免整页都是框线。
///
/// 以前这段样式在新建通知页、对话框、屏蔽词页各抄了一份，改一处就漏两处；
/// 统一收敛到这里，新页面直接用 `WarmField`。
class WarmField extends StatelessWidget {
  const WarmField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.autofocus = false,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  static const double radius = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill =
        isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF2EADC);
    final textColor = isDark ? const Color(0xFFEDE4D3) : const Color(0xFF3B3226);
    final hintColor = isDark ? Colors.white38 : const Color(0xFFA39A89);
    final border = BorderRadius.circular(radius);
    final noSide = OutlineInputBorder(
      borderRadius: border,
      borderSide: BorderSide.none,
    );

    return TextField(
      controller: controller,
      maxLines: maxLines,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      textCapitalization: textCapitalization,
      style: TextStyle(fontSize: 15, color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 15, color: hintColor),
        filled: true,
        fillColor: fill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: noSide,
        enabledBorder: noSide,
        focusedBorder: OutlineInputBorder(
          borderRadius: border,
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

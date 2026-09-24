import 'package:flutter/material.dart';

/// 半透明「玻璃卡」：白底蒙板 + 圆角 + 柔和阴影 + 顶部 specular 高光。
///
/// 比 LiquidGlassLite 轻得多（每张卡不做实时模糊），但在极光背景上视觉上
/// 已经足够"玻璃感"，且长列表滚动不掉帧。
///
/// 亮色模式：白色蒙板 α=0.62，背后的极光颜色会透出来一点点；文字对比度靠
/// 蒙板保证。
/// 暗色模式：白色蒙板 α=0.08（深色玻璃质感），文字靠主题色保证。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final fill = isDark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFFDFBF7).withOpacity(0.68);
    final border = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color(0xFFF7F1E4).withOpacity(0.90);
    final shadow = isDark
        ? Colors.black.withOpacity(0.35)
        : const Color(0xFF5C4A32).withOpacity(0.10);
    final highlight = isDark
        ? Colors.white.withOpacity(0.18)
        : const Color(0xFFFFFDF8).withOpacity(0.90);

    final radius = BorderRadius.circular(borderRadius);

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // 顶部 specular 高光（细线，模拟玻璃顶部反光）
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        highlight.withOpacity(0),
                        highlight,
                        highlight.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (padding != null)
              Padding(padding: padding!, child: child)
            else
              child,
          ],
        ),
      ),
    );
  }
}
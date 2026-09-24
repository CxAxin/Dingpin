import 'package:flutter/material.dart';

/// Warm "paper & sunlight" backdrop (Wonderous-style editorial warmth):
/// one warm parchment linear base + three desaturated warm radial glows
/// (apricot / terracotta / honey) at different positions so the bottom
/// liquid-glass tab always has something to refract — but everything stays
/// in ONE warm family for a calm, premium, magazine feel.
///
/// Pure widget tree, no image assets — works in light & dark mode.
///
/// 原本是 `main_screen.dart` 里的私有组件，只有首页用得上；结果是二级页面
/// （屏蔽词管理、新建通知）都落在纯色 Scaffold 背景上，`GlassCard` 没有可
/// 透出的底色，"玻璃感"就没了。抽到这里后所有页面共用同一张背景。
class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({
    super.key,
    required this.brightness,
    this.showBottomGlow = true,
    this.child,
  });

  final Brightness brightness;

  /// 中下方那束暖光主要是给底部玻璃 Tab 栏当"光源"用的；
  /// 没有玻璃 Tab 的二级页面可以关掉，避免底部过亮影响列表可读性。
  final bool showBottomGlow;

  /// 铺在背景之上的内容。**二级页请把整个 `Scaffold` 放进来**：
  ///
  /// ```dart
  /// AuroraBackdrop(child: Scaffold(backgroundColor: Colors.transparent, ...))
  /// ```
  ///
  /// 这样 AppBar 透明后能直接透出暖金纸感，而且 Scaffold 会正常为 AppBar
  /// 让出高度，内容不用（也绝不应该）再手动让一个 `kToolbarHeight`。
  /// 之前"Scaffold + extendBodyBehindAppBar + SizedBox(kToolbarHeight)"的
  /// 写法会把工具栏高度算两遍，标题和正文之间空出一整条工具栏的空白。
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;

    // 底层线性渐变：暖金纸感托底（Wonderous 米金），保证背景不会是纯色。
    final base = isDark
        ? const [Color(0xFF1C1917), Color(0xFF26221E), Color(0xFF2B2620)]
        : const [Color(0xFFF5EFE6), Color(0xFFEFE7DA), Color(0xFFEAE0CE)];

    // 三个暖色光斑（同族降饱和：杏 / 陶土 / 蜜），明暗两套。
    final blobs = isDark
        ? const [
            (Color(0xFFD9A06B), 0.28), // 淡杏
            (Color(0xFFB08968), 0.30), // 陶土
            (Color(0xFFCC9C60), 0.22), // 蜜
          ]
        : const [
            (Color(0xFFEBB98A), 0.55), // 淡杏
            (Color(0xFFC49A6C), 0.45), // 陶土
            (Color(0xFFDDB878), 0.40), // 蜜
          ];

    // 背景是**静态**的（4 个大径向渐变 + 1 张线性渐变底），但它是 Stack 的
    // 第一个孩子，没有独立 layer 的话，上面列表每滚动一帧、页面每转场一帧，
    // 这 5 层渐变都要跟着重画一遍 —— 中低端机上这就是掉帧的主因之一。
    // RepaintBoundary 把它单独缓存成一张纹理，之后只在尺寸/主题变化时重绘。
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: base,
          ),
        ),
        child: Stack(
          children: [
            // 杏色光斑 — 左上
            Positioned(
              top: -120,
              left: -80,
              child: IgnorePointer(
                child: _Blob(
                  size: 420,
                  color: blobs[0].$1.withOpacity(blobs[0].$2),
                ),
              ),
            ),
            // 陶土光斑 — 右下（最大，给玻璃 Tab 提供底色折射）
            Positioned(
              bottom: -180,
              right: -100,
              child: IgnorePointer(
                child: _Blob(
                  size: 520,
                  color: blobs[1].$1.withOpacity(blobs[1].$2),
                ),
              ),
            ),
            // 蜜色光斑 — 右上
            Positioned(
              top: -60,
              right: -120,
              child: IgnorePointer(
                child: _Blob(
                  size: 360,
                  color: blobs[2].$1.withOpacity(blobs[2].$2),
                ),
              ),
            ),
            // 中下补一束暖光，让玻璃 Tab 跨过的区域有"光源"
            if (showBottomGlow)
              Positioned(
                bottom: 80,
                left: 40,
                child: IgnorePointer(
                  child: _Blob(
                    size: 260,
                    color: blobs[0].$1.withOpacity(isDark ? 0.18 : 0.30),
                  ),
                ),
              ),
            // 内容层（若传入）盖在所有光斑之上。
            if (child != null) Positioned.fill(child: child!),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

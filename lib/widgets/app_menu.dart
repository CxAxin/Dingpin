import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// 「顶顶」弹出菜单的统一外观 + 快速弹出实现。
///
/// 为什么不用系统 `showMenu`：
/// 1. 它是 `PopupMenuRoute`，入场动画写死约 300ms，长按后要等路由推入 +
///    布局完成才出现，手感「卡、慢」；
/// 2. 默认 4px 小圆角 + 灰白底，跟 App 的暖金玻璃卡风格不搭。
/// 这里改成自绘的 `PopupRoute`：150ms 淡入 + 轻微缩放，**缩放原点落在被长按
/// 的那一行上**（不是菜单自己的中心）——菜单看上去是从手指底下长出来的，
/// 而不是凭空在屏幕中间"放大"出来；退出再快 20%（120ms）。
/// 点选立即关闭，同时保留系统菜单该有的行为——点外部关闭、返回键关闭。
class AppMenu {
  const AppMenu._();

  static const double radius = 20;
  static const double itemHeight = 46;
  static const double iconSize = 19;

  /// 删除这类破坏性操作用红色，和普通条目区分开。
  static const Color danger = Color(0xFFB3261E);

  /// 入场动画时长。系统菜单是 300ms，这里砍一半，长按后「几乎立刻」出现。
  /// 退出比进入快一档：东西离开屏幕就该干脆，没必要让用户等着它走完。
  static const Duration _duration = AppMotion.menuIn;
  static const Duration _reverseDuration = AppMotion.menuOut;

  /// 全站统一的进入曲线（见 [AppMotion.enter]）。
  static const Curve _enterCurve = AppMotion.enter;

  static bool _isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  static Color surface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF2E2823) : const Color(0xFFFDFBF7);

  static Color border(BuildContext c) =>
      _isDark(c) ? Colors.white.withOpacity(0.10) : const Color(0xFFEADFC8);

  static Color iconColor(BuildContext c) =>
      _isDark(c) ? const Color(0xFFC9B99A) : const Color(0xFF6B5B45);

  static Color textColor(BuildContext c) =>
      _isDark(c) ? const Color(0xFFEDE4D3) : const Color(0xFF3B3226);

  /// 20px 圆角 + 一圈很淡的暖色描边（阴影之外再给一点轮廓感）。
  static ShapeBorder shape(BuildContext c) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: border(c), width: 0.5),
      );

  // ── 下面两个是给 AppBar 右上角三点菜单（PopupMenuButton）用的 ──────────
  // PopupMenuButton 的 itemBuilder 只能返回 PopupMenuItem，没法用 AppMenu.show，
  // 所以这两条旧 API 要保留。长按菜单请一律走 AppMenu.show + AppMenuEntry。

  /// 单条菜单项：图标 + 文字。图标尺寸、颜色、左侧间距全站统一，
  /// 这样即使各页面图标不同，整体依然是对齐的。
  static PopupMenuItem<String> item({
    required String value,
    required IconData icon,
    required String label,
    bool isDanger = false,
    VoidCallback? onTap,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: itemHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
      child: Builder(
        builder: (ctx) {
          return Row(
            children: [
              Icon(
                icon,
                size: iconSize,
                color: isDanger ? danger : iconColor(ctx),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDanger ? danger : textColor(ctx),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static PopupMenuDivider divider(BuildContext c) =>
      PopupMenuDivider(height: 1, color: border(c));

  /// 在 [context]（被长按的那一行）附近弹出菜单。
  ///
  /// 位置以该行中心为锚点，并自动收进屏幕内（靠边时向内让 12px）。
  static Future<T?> show<T>({
    required BuildContext context,
    required List<AppMenuEntry> items,
  }) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return Future<T?>.value();
    }
    return Navigator.of(context, rootNavigator: true).push<T>(
      _FastMenuRoute<T>(
        items: items,
        anchorTopLeft: renderObject.localToGlobal(Offset.zero),
        anchorSize: renderObject.size,
      ),
    );
  }
}

/// 一条菜单项。图标 + 文字；[isDanger] 用于删除等破坏性操作（红色）。
class AppMenuEntry {
  const AppMenuEntry({
    required this.icon,
    required this.label,
    this.isDanger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDanger;
  final VoidCallback? onTap;
}

/// 自绘的菜单路由：只负责「淡入 + 缩放 + 点外部关闭」，
/// 具体定位与外观交给 [_MenuHost]。
class _FastMenuRoute<T> extends PopupRoute<T> {
  _FastMenuRoute({
    required this.items,
    required this.anchorTopLeft,
    required this.anchorSize,
  });

  final List<AppMenuEntry> items;
  final Offset anchorTopLeft;
  final Size anchorSize;

  @override
  Duration get transitionDuration => AppMenu._duration;

  @override
  Duration get reverseTransitionDuration => AppMenu._reverseDuration;

  @override
  bool get barrierDismissible => true;

  /// 极淡的遮罩：只用来把菜单「托」起来，不压暗背景。
  @override
  Color? get barrierColor => const Color(0x0F000000);

  @override
  String? get barrierLabel => 'Dismiss menu';

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _MenuHost(
      animation: animation,
      items: items,
      anchorTopLeft: anchorTopLeft,
      anchorSize: anchorSize,
      surface: AppMenu.surface(context),
      border: AppMenu.border(context),
      iconColor: AppMenu.iconColor(context),
      textColor: AppMenu.textColor(context),
      shape: AppMenu.shape(context),
    );
  }

  /// 菜单自身已经带了淡入 + 缩放，这里不要再套一层全屏动画，
  /// 否则缩放会以屏幕中心为原点，菜单会「飘」。遮罩由路由自己淡入。
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

/// 把菜单摆到长按位置附近，并播放入场动画。
class _MenuHost extends StatelessWidget {
  const _MenuHost({
    required this.animation,
    required this.items,
    required this.anchorTopLeft,
    required this.anchorSize,
    required this.surface,
    required this.border,
    required this.iconColor,
    required this.textColor,
    required this.shape,
  });

  final Animation<double> animation;
  final List<AppMenuEntry> items;
  final Offset anchorTopLeft;
  final Size anchorSize;
  final Color surface;
  final Color border;
  final Color iconColor;
  final Color textColor;
  final ShapeBorder shape;

  static const double _hPad = 16;
  static const double _vPad = 6;
  static const double _gap = 14;
  static const double _edge = 12;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;

    // 宽度按最长的一条文字量出来，菜单才不会「虚胖」或挤字。
    const labelStyle = TextStyle(fontSize: 14);
    final direction = Directionality.of(context);
    var widestLabel = 0.0;
    for (final entry in items) {
      final painter = TextPainter(
        text: TextSpan(text: entry.label, style: labelStyle),
        maxLines: 1,
        textDirection: direction,
      )..layout();
      if (painter.width > widestLabel) widestLabel = painter.width;
    }

    var maxWidth = screen.width - _edge * 2;
    if (maxWidth < 150) maxWidth = 150;
    final width = (_hPad + AppMenu.iconSize + _gap + widestLabel + _hPad)
        .clamp(150, maxWidth)
        .toDouble();

    // 条目之间夹 1px 分隔线，最后一条后面不画。
    final height = _vPad * 2 +
        items.length * AppMenu.itemHeight +
        (items.length - 1) * 1.0;

    // 水平：以长按行的中心为准，靠边时向内让。
    final anchorCenterX = anchorTopLeft.dx + anchorSize.width / 2;
    var left = anchorCenterX - width / 2;
    final maxLeft = screen.width - width - _edge;
    if (left > maxLeft) left = maxLeft;
    if (left < _edge) left = _edge;

    // 垂直：菜单顶部落在长按行中心附近（手指下方展开），越界则回缩。
    final anchorCenterY = anchorTopLeft.dy + anchorSize.height / 2;
    var top = anchorCenterY - 12;
    final maxTop = screen.height - height - _edge - media.viewInsets.bottom;
    if (top > maxTop) top = maxTop;
    final minTop = media.padding.top + 8;
    if (top < minTop) top = minTop;

    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMenu._enterCurve,
    );

    // 缩放原点：菜单是被"长按的那一行"唤出来的，就该从那一行长出来。
    // 把锚点中心换算成菜单自己的对齐坐标（-1..1），再收进边界。
    final anchorOrigin = Alignment(
      ((anchorCenterX - left) / width * 2 - 1).clamp(-1.0, 1.0),
      ((anchorCenterY - top) / height * 2 - 1).clamp(-1.0, 1.0),
    );

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              alignment: anchorOrigin,
              scale: Tween<double>(
                begin: AppMotion.panelEnterScale,
                end: 1,
              ).animate(curved),
              child: Material(
                color: surface,
                elevation: 8,
                shape: shape,
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: _vPad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Container(height: 1, color: border),
                          ),
                        _MenuRow(
                          entry: items[i],
                          iconColor: iconColor,
                          textColor: textColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 单条菜单项。点下去立刻关闭路由再执行动作——先关再干活，手感才「跟手」。
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.entry,
    required this.iconColor,
    required this.textColor,
  });

  final AppMenuEntry entry;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final isDanger = entry.isDanger;
    return InkWell(
      onTap: () {
        Navigator.of(context).maybePop();
        entry.onTap?.call();
      },
      child: SizedBox(
        height: AppMenu.itemHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                entry.icon,
                size: AppMenu.iconSize,
                color: isDanger ? AppMenu.danger : iconColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDanger ? AppMenu.danger : textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

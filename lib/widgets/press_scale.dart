import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// 按下瞬间缩一下的通用反馈壳。
///
/// 为什么需要它：
/// * `ListTile` / `InkWell` 自带水波纹 + 长按震动，按下去有反应；
/// * 裸 `GestureDetector` **什么都不给**——既不水波纹也不震动，点上去像
///   戳在一张图上。历史页的卡片是自建组合（玻璃卡 + ListTile），正是后者。
///
/// 反馈规则（比视觉更重要的是「什么时候」反馈）：
/// * 反馈发生在**按下的那一刻**（指针落下），不是松开、也不是点击生效时。
///   手指一碰就有反应，才有「按到了」的感觉；等到松手才动会像延迟。
/// * 缩放幅度很小（默认 0.97），动作很短（130ms），任何一端过头都会显得廉价。
/// * 缩到一半就滑走（取消）时立刻回弹，不留残影。
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.scale = AppMotion.pressScale,
  });

  final Widget child;

  /// 抬手（没滑出范围）时触发。
  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  /// 不可交互时既不缩放也不响应手势——列表项正在离场时用这个避免误触。
  final bool enabled;

  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    if (!mounted) return;
    setState(() => _down = value);
  }

  @override
  void didUpdateWidget(PressScale old) {
    super.didUpdateWidget(old);
    // 变成不可交互的瞬间把按下态收掉，免得卡片停在缩小的样子。
    if (!widget.enabled && _down) {
      setState(() => _down = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    // AnimatedScale 在测试环境（`tester.pump()` 逐帧推进）里也会走，但它是
    // transform-only，不会引入额外的离屏缓冲，成本可以忽略。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _setDown(false);
              // GestureDetector 不会自动震动（InkWell 会），这里手动补上，
              // 让自建卡片和 ListTile 页的手感一致。
              Feedback.forLongPress(context);
              widget.onLongPress!.call();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: AppMotion.press,
        curve: AppMotion.enter,
        child: widget.child,
      ),
    );
  }
}

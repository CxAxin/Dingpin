import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/motion.dart';

/// 全站统一的页面转场。
///
/// 为什么不用默认的 `MaterialPageRoute`：Android 默认转场是「整页从底部
/// 推上来」，位移距离大、持续 300ms，在叠了液态玻璃 TabBar 的页面上很容易
/// 掉帧，观感也偏"重"。这里改成 Material motion 里的 **Fade Through** 变体：
///
/// * 新页面：从下方 **24px** 轻轻上浮 + 淡入 + 0.97 → 1 的极轻缩放；
/// * 旧页面：**保持静止**（不做动画）。
///
/// 只动一层是刻意的——两个页面同时做变换意味着每帧要合成两层动画，是这类
/// 页面掉帧最常见的原因。
///
/// ## 为什么会掉帧，以及这里怎么解决
///
/// 转场里最贵的从来不是"动画本身"，而是**每帧都要把整屏内容重新画一遍**：
///
/// * `Opacity` 会生成一层 OpacityLayer，整屏先进离屏缓冲再混合，老 GPU 上很慢；
/// * `Transform.scale` 会让这一层失去光栅缓存，因为缩放值每帧都在变，
///   意味着**整屏每帧重新栅格化**。
///
/// Flutter 官方的 Android Q 缩放转场（`ZoomPageTransitionsBuilder`）踩的是同一个
/// 坑，它的解法是：转场开始时把整页**快照（snapshot）成一张纹理**，动画期间
/// 每帧只做一次 `drawImageRect`。这里照搬同一套手法 ——
/// [_AppPageTransition] 用 `SnapshotWidget` 包住页面，由
/// [_AppPageTransitionPainter] 在**一次绘制调用**里同时完成淡入、位移、缩放，
/// 全程不产生任何 Layer。
///
/// 快照只在动画真正跑的时候开着（`SnapshotController.allowSnapshotting`），
/// 动画一停立刻关掉、回到正常绘制路径，所以静态页面不会有额外开销，也不会
/// 因为一直显示纹理而牺牲清晰度。
///
/// 已知取舍：快照会把页面内的动画**短暂冻结**这 240ms（此期间画面是张静态
/// 图，触摸本身照常响应）。页面都是在入场/退场的极短时间内，感知不到。
///
/// 用法：把 `MaterialPageRoute(builder: ...)` 换成
/// `AppPageRoute(builder: ...)`。
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
    this.instant = false,
  }) : super(
          // 磁贴直达这类场景要"页面已经在那里"，不能有任何入场动画。
          transitionDuration:
              instant ? Duration.zero : AppMotion.pageIn,
          reverseTransitionDuration:
              instant ? Duration.zero : AppMotion.pageOut,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (instant) return child;
            return _AppPageTransition(animation: animation, child: child);
          },
        );

  /// `true` 时页面瞬间出现（无动画）。用于通知栏磁贴「直达新建」：Dart 侧在
  /// Activity 拉起之前就把路由压好，Activity 首帧渲染时编辑页已经在栈里，
  /// 用户看到的就是直接进编辑页，中间不会闪过主界面。
  final bool instant;

  /// 无动画版的便捷入口（磁贴 / 外部直达场景）。
  factory AppPageRoute.instant({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) =>
      AppPageRoute<T>(builder: builder, settings: settings, instant: true);
}

class _AppPageTransition extends StatefulWidget {
  const _AppPageTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_AppPageTransition> createState() => _AppPageTransitionState();
}

class _AppPageTransitionState extends State<_AppPageTransition> {
  final SnapshotController _controller = SnapshotController();
  late _AppPageTransitionPainter _painter;

  // 位移只有 3% 屏高（约 24px），缩放 0.97→1：够"活"，又不至于让整屏像素
  // 每帧重排。
  static final Animatable<Offset> _slideIn =
      Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
          .chain(CurveTween(curve: AppMotion.enter));
  static final Animatable<double> _scaleIn =
      Tween<double>(begin: AppMotion.pageEnterScale, end: 1.0)
          .chain(CurveTween(curve: AppMotion.enter));

  late Animation<Offset> _slide = _slideIn.animate(widget.animation);
  late Animation<double> _scale = _scaleIn.animate(widget.animation);

  // 只有动画真的在跑时才值得快照：静止时走正常绘制路径，清晰、零额外内存。
  bool get _useSnapshot => !kIsWeb;

  void _updateSnapshotting() {
    final Animation<Offset> slide = _slide;
    final Animation<double> scale = _scale;
    final bool settled = scale.value == 1.0 &&
        slide.value == Offset.zero &&
        (widget.animation.value == 0.0 || widget.animation.value == 1.0);
    _controller.allowSnapshotting = !settled && _useSnapshot;
  }

  void _onStatusChange(AnimationStatus status) {
    _controller.allowSnapshotting = status.isAnimating && _useSnapshot;
  }

  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_updateSnapshotting);
    widget.animation.addStatusListener(_onStatusChange);
    _painter = _AppPageTransitionPainter(
      animation: widget.animation,
      slide: _slide,
      scale: _scale,
    );
    // 首帧可能就已经在动画中（比如动画开了一半才插入图层）。
    _updateSnapshotting();
  }

  @override
  void didUpdateWidget(covariant _AppPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_updateSnapshotting);
      oldWidget.animation.removeStatusListener(_onStatusChange);
      widget.animation.addListener(_updateSnapshotting);
      widget.animation.addStatusListener(_onStatusChange);
      _slide = _slideIn.animate(widget.animation);
      _scale = _scaleIn.animate(widget.animation);
      _painter.dispose();
      _painter = _AppPageTransitionPainter(
        animation: widget.animation,
        slide: _slide,
        scale: _scale,
      );
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_updateSnapshotting);
    widget.animation.removeStatusListener(_onStatusChange);
    _controller.dispose();
    _painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SnapshotWidget(
      painter: _painter,
      controller: _controller,
      // 页面上理论上没有 platform view，但真要混进来也不该直接崩。
      mode: SnapshotMode.permissive,
      // 键盘弹出、状态栏变化导致页面尺寸改变时重新取快照。
      autoresize: true,
      child: widget.child,
    );
  }
}

/// 把入场动画（淡入 + 上浮 + 极轻缩放）画出来。
///
/// 有两条分支，观感必须完全一致：
/// * [paintSnapshot]：动画期间，页面已经被拍成一张 `ui.Image`，所有变换都在
///   一次 `drawImageRect` 里完成 —— 不 push 任何 Layer，没有离屏缓冲；
/// * [paint]：没开快照时（动画已停 / 不支持快照），走传统的 pushTransform +
///   pushOpacity，包住子树的正常绘制。
class _AppPageTransitionPainter extends SnapshotPainter {
  _AppPageTransitionPainter({
    required this.animation,
    required this.slide,
    required this.scale,
  }) {
    animation.addListener(notifyListeners);
    animation.addStatusListener(_onStatusChange);
    slide.addListener(notifyListeners);
    scale.addListener(notifyListeners);
  }

  void _onStatusChange(AnimationStatus _) => notifyListeners();

  final Animation<double> animation;
  final Animation<Offset> slide;
  final Animation<double> scale;

  final Matrix4 _transform = Matrix4.zero();
  final LayerHandle<TransformLayer> _transformHandle =
      LayerHandle<TransformLayer>();
  final LayerHandle<OpacityLayer> _opacityHandle = LayerHandle<OpacityLayer>();

  @override
  void paint(
    PaintingContext context,
    ui.Offset offset,
    Size size,
    PaintingContextCallback painter,
  ) {
    if (!animation.isAnimating) {
      painter(context, offset);
      return;
    }
    _updateTransform(_transform, size);
    _transformHandle.layer = context.pushTransform(
      true,
      offset,
      _transform,
      (PaintingContext context, Offset offset) {
        _opacityHandle.layer = context.pushOpacity(
          offset,
          (opacity * 255).round(),
          painter,
          oldLayer: _opacityHandle.layer,
        );
      },
      oldLayer: _transformHandle.layer,
    );
  }

  @override
  void paintSnapshot(
    PaintingContext context,
    Offset offset,
    Size size,
    ui.Image image,
    Size sourceSize,
    double pixelRatio,
  ) {
    final double alpha = opacity;
    if (alpha <= 0.0) return;

    // sourceSize 是物理像素，先换算回逻辑像素，再套缩放。
    final double width = sourceSize.width / pixelRatio;
    final double height = sourceSize.height / pixelRatio;
    final double scaledWidth = width * scale.value;
    final double scaledHeight = height * scale.value;
    // 缩放以中心为原点（和 paint 分支的 pushTransform 对齐），平移也在这里
    // 一并算进去：整段动画就这一次 drawImageRect。
    final Rect dst = Rect.fromLTWH(
      offset.dx + (width - scaledWidth) / 2 + slide.value.dx * width,
      offset.dy + (height - scaledHeight) / 2 + slide.value.dy * height,
      scaledWidth,
      scaledHeight,
    );
    final Paint paint = Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..color = Color.fromRGBO(0, 0, 0, alpha);
    context.canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      paint,
    );
  }

  double get opacity => animation.value.clamp(0.0, 1.0);

  void _updateTransform(Matrix4 transform, Size size) {
    transform.setIdentity();
    transform.translateByDouble(slide.value.dx * size.width,
        slide.value.dy * size.height, 0, 1);
    final double s = scale.value;
    if (s == 1.0) return;
    transform.scaleByDouble(s, s, s, 1);
    final double dx = ((size.width * s) - size.width) / 2;
    final double dy = ((size.height * s) - size.height) / 2;
    transform.translateByDouble(-dx, -dy, 0, 1);
  }

  @override
  void dispose() {
    animation.removeListener(notifyListeners);
    animation.removeStatusListener(_onStatusChange);
    slide.removeListener(notifyListeners);
    scale.removeListener(notifyListeners);
    _transformHandle.layer = null;
    _opacityHandle.layer = null;
    super.dispose();
  }

  @override
  bool shouldRepaint(covariant _AppPageTransitionPainter oldPainter) {
    return oldPainter.animation.value != animation.value ||
        oldPainter.slide.value != slide.value ||
        oldPainter.scale.value != scale.value;
  }
}

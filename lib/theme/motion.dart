import 'package:flutter/material.dart';

/// 全站动效参数集中在这里。
///
/// 为什么要单独抽出来：之前每个组件各写一套曲线和时长，页面转场、菜单、
/// 横幅、FAB 各自为政，改一处漏一处，观感很难统一。这里定一套，各处引用。
///
/// 取值规则（经验值，来自 animations.dev 那一派）：
/// * UI 动画一律 **< 300ms**，超过就开始有「等待」感；
/// * 出现/进入用**强 ease-out**（起步快、尾段长），元素看起来被"甩到位"；
/// * 退出比进入**快约 20%**——东西离开屏幕就该干脆，别让用户等它走完；
/// * 缩放**永不到 0**（`scale(0)` 会让元素凭空消失，很廉价），
///   小元素 0.92、整页 0.97 起。
class AppMotion {
  const AppMotion._();

  /// 进入 / 出现：`cubic-bezier(0.23, 1, 0.32, 1)`。
  static const Curve enter = Cubic(0.23, 1.0, 0.32, 1.0);

  /// 元素在屏幕内移动：两端都收的对称曲线 `cubic-bezier(0.77, 0, 0.175, 1)`。
  static const Curve move = Cubic(0.77, 0.0, 0.175, 1.0);

  /// 页面转场。退出比进入快约 25%。
  static const Duration pageIn = Duration(milliseconds: 240);
  static const Duration pageOut = Duration(milliseconds: 180);

  /// 弹出菜单：要"跟手"，明显快于页面转场。
  static const Duration menuIn = Duration(milliseconds: 150);
  static const Duration menuOut = Duration(milliseconds: 120);

  /// 底部横幅、浮层这类小提示。
  static const Duration bannerIn = Duration(milliseconds: 220);
  static const Duration bannerOut = Duration(milliseconds: 176);

  /// 列表项的增删过渡。
  static const Duration itemIn = Duration(milliseconds: 200);
  static const Duration itemOut = Duration(milliseconds: 150);

  /// 按压反馈：短到几乎感觉不到延迟，又足以看清「按下去了」。
  static const Duration press = Duration(milliseconds: 130);

  /// 按下时缩到多少。再小就显得糊再膨胀回来了。
  static const double pressScale = 0.97;

  /// 菜单、对话框这类小面板的入场起点。
  static const double panelEnterScale = 0.92;

  /// 整页入场的起点（页面太大，0.97 就够，再多会看到边缘）。
  static const double pageEnterScale = 0.97;
}

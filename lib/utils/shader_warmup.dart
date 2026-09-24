import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// 提前把本 app 真正会用到的 shader 编译掉。
///
/// 「卡卡的」很多时候不是帧率不够，而是**第一次**用到某个效果时现场编译
/// shader（渐变、模糊阴影、圆角裁剪都各有一条），那一帧会突然掉到十几帧。
/// Flutter 在首帧之后会跑一次 [PaintingBinding.shaderWarmUp]，这里换成一份
/// 按本项目实际视觉元素定制的清单，把首次进入编辑页 / 首次弹菜单 / 首次
/// 弹玻璃对话框时的编译抖动提前消化在启动阶段。
///
/// 做法参考 Flutter 官方 Wonderous 示例（同一套思路：把 app 里最贵的绘制
/// 命令在小画布上先跑一遍）。
class AppShaderWarmUp extends ShaderWarmUp {
  const AppShaderWarmUp();

  /// Canvas 尺寸：够画出下面这些形状即可，越小越快。
  /// 基类默认只有 100×100，画不下下面这几种形状，这里放大到 300。
  static const double _size = 300;

  @override
  ui.Size get size => const ui.Size(_size, _size);

  @override
  Future<void> warmUpOnCanvas(ui.Canvas canvas) async {
    // ── 1. 圆角矩形 + 模糊阴影（GlassCard / 菜单 / 对话框） ──────────
    // 阴影的 blur 是最贵的一条：它要跑一趟高斯模糊的 shader。
    const shadow = BoxShadow(
      color: Color(0x1A5C4A32),
      blurRadius: 20,
      offset: Offset(0, 8),
    );
    const rrect = ui.RRect.fromLTRBXY(20, 20, 260, 160, 20, 20);
    canvas.saveLayer(null, ui.Paint());
    canvas.drawRRect(rrect, shadow.toPaint());
    canvas.drawRRect(rrect, ui.Paint()..color = const Color(0xADFDFBF7));
    canvas.drawRRect(
      rrect,
      ui.Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();

    // ── 2. 线性渐变（AuroraBackdrop 底层纸感） ──────────────────────
    final linear = ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        const ui.Offset(_size, _size),
        const [Color(0xFFF5EFE6), Color(0xFFEFE7DA), Color(0xFFEAE0CE)],
      );
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, _size, _size), linear);

    // ── 3. 径向渐变（AuroraBackdrop 的三团光斑） ────────────────────
    // 背景是 4 个大 radial gradient，不预编译的话首帧就会卡一下。
    final radial = ui.Paint()
      ..shader = ui.Gradient.radial(
        const ui.Offset(120, 120),
        140,
        const [Color(0x8CEBB98A), Color(0x00EBB98A)],
      );
    canvas.drawCircle(const ui.Offset(120, 120), 140, radial);

    // ── 4. 圆角裁剪（ClipRRect，玻璃卡里的高光条靠它） ──────────────
    canvas.save();
    canvas.clipRRect(const ui.RRect.fromLTRBXY(20, 20, 260, 40, 12, 12));
    canvas.drawRect(
      const ui.Rect.fromLTWH(20, 20, 240, 20),
      ui.Paint()..color = const Color(0x66FFFDF8),
    );
    canvas.restore();

    // ── 5. 文本（列表标题 / 正文，文字渲染也有自己的 shader） ────────
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: 15, fontStyle: ui.FontStyle.normal),
    )..addText('Dingpin');
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 200));
    canvas.drawParagraph(paragraph, const ui.Offset(20, 220));
  }
}

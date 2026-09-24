// 回归测试：二级页「标题 → 正文」的间距。
//
// 背景必须铺在 Scaffold **外面**：
//
//     AuroraBackdrop(child: Scaffold(backgroundColor: Colors.transparent, ...))
//
// 曾经的写法是 `Scaffold + extendBodyBehindAppBar: true + Stack + 手动让一个
// kToolbarHeight`。问题在于 Scaffold 在 extendBodyBehindAppBar 下**已经**把
// 工具栏算进 body 的起点，再手动让一次就把高度算了两遍 —— 实测 AppBar 底边
// 到正文空出 64px（多出整整一条工具栏），用户 2026-09-19 截图指出。
// 这里把结论钉死，防止有人再改回去。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pinnit_flutter/widgets/aurora_backdrop.dart';

/// 让测试里也有状态栏，否则 SafeArea 的 top 退化成 0，测不出真机表现。
const _statusBar = 44.0;
const _screen = Size(400, 800);

/// 把测试视口调成一台普通手机：400x800、状态栏 44、dpr 1。
void _setUpScreen(WidgetTester tester) {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = const FakeViewPadding(top: _statusBar);
  addTearDown(tester.view.reset);
}

Widget _page() => AuroraBackdrop(
      brightness: Brightness.light,
      showBottomGlow: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text('TITLE'),
        ),
        body: SafeArea(
          top: false,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: EdgeInsets.only(top: 8), child: Text('HINT')),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('二级页标题与正文之间不留整条工具栏', (tester) async {
    _setUpScreen(tester);
    await tester.pumpWidget(MaterialApp(home: _page()));

    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    final hintTop = tester.getTopLeft(find.text('HINT')).dy;
    final gap = hintTop - appBarBottom;

    // 期望：只有说明文字自己那 8px 的上边距。
    expect(
      gap,
      lessThanOrEqualTo(12),
      reason: 'AppBar 底到正文应为个位数留白，实测 $gap '
          '（若接近 64，说明又手动让了一次 kToolbarHeight）',
    );
  });

  testWidgets('背景铺满整屏，包括状态栏和透明顶栏后面', (tester) async {
    _setUpScreen(tester);
    await tester.pumpWidget(MaterialApp(home: _page()));

    final backdrop = tester.getRect(find.byType(AuroraBackdrop));
    expect(backdrop.top, 0, reason: '背景应从屏幕最顶端开始，顶栏才能透出暖金纸感');
    expect(backdrop.height, _screen.height);
  });
}

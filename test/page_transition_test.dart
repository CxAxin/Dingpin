// 回归测试：页面转场期间走快照，静止后立即回到正常绘制。
//
// 为什么要在意：整页做缩放会让那一层失去光栅缓存，**整屏每帧重新栅格化**，
// 叠上液态玻璃 TabBar 时就是用户说的「卡卡的」。官方 Android Q 缩放转场用
// SnapshotWidget 规避（page_transitions_theme.dart），这里照做。
//
// 关键点是"动画一停必须把快照关掉"：一直开着的话页面是一张静态纹理，
// 白白占内存、清晰度受损，页面里的动画也会被冻住。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pinnit_flutter/widgets/app_page_route.dart';

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Widget _app() => MaterialApp(
      navigatorKey: _navKey,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push<void>(
                AppPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Center(child: Text('PAGE 2')),
                  ),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('转场期间用快照，结束后关掉', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.tap(find.text('go'));
    await tester.pump();

    // 动画进行中。
    await tester.pump(const Duration(milliseconds: 100));
    final SnapshotWidget during =
        tester.widget<SnapshotWidget>(find.byType(SnapshotWidget));
    expect(during.controller.allowSnapshotting, isTrue,
        reason: '转场时应该把整页拍成纹理，避免整屏每帧重栅格化');

    // 动画走完。
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final SnapshotWidget after =
        tester.widget<SnapshotWidget>(find.byType(SnapshotWidget));
    expect(after.controller.allowSnapshotting, isFalse,
        reason: '静止后必须关掉快照，否则页面一直是张静态图');

    // 页面本身照常渲染出来。
    expect(find.text('PAGE 2'), findsOneWidget);
  });

  testWidgets('返回时同样走快照', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE 2'), findsOneWidget);

    // 触发返回。这里用 navigatorKey 而不是 tester.pageBack()：后者要页面上真
    // 有一个返回按钮才行（找的是 CupertinoNavigationBarBackButton），
    // 而本测试的第二页故意只放了一个 Text。
    await _navKey.currentState!.maybePop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final SnapshotWidget leaving =
        tester.widget<SnapshotWidget>(find.byType(SnapshotWidget));
    expect(leaving.controller.allowSnapshotting, isTrue);

    // 退场动画结束。
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('instant 路由不做任何动画', (tester) async {
    await tester.pumpWidget(_app());

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push<void>(
              AppPageRoute<void>.instant(
                builder: (_) => const Scaffold(
                  body: Center(child: Text('INSTANT')),
                ),
              ),
            ),
            child: const Text('tile'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('tile'));
    await tester.pump();
    // 无转场 → 不应该出现 SnapshotWidget 那一层。
    expect(find.byType(SnapshotWidget), findsNothing);
    expect(find.text('INSTANT'), findsOneWidget);
  });
}

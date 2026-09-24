// 回归测试：列表增删必须有过渡。
//
// 之前两个列表页都是 `ListView.separated`：数据一变，整行瞬间消失/出现，
// 下面的内容跟着跳一格。这里验证换成 AppAnimatedList 之后，删除的那一行会
// 留在树里把高度收完才走（= 相邻内容是被"吸上来"的，不是跳上来的）。
//
// 顺带验证：大批量变化（搜索过滤、清空历史）不走逐项动画，而是整表重建，
// 否则几十上百张卡片一起飞会很糟，也很容易拖垮帧率。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pinnit_flutter/widgets/app_animated_list.dart';

Widget _app(List<String> items) => MaterialApp(
      home: Scaffold(
        body: AppAnimatedList<String>(
          items: items,
          idOf: (s) => s,
          itemBuilder: (_, s) => SizedBox(
            height: 60,
            child: Center(child: Text(s)),
          ),
          removedItemBuilder: (_, s) => SizedBox(
            height: 60,
            child: Center(child: Text('$s (leaving)')),
          ),
        ),
      ),
    );

void main() {
  testWidgets('删除一项：这一行先收起、走完才消失', (tester) async {
    await tester.pumpWidget(_app(['a', 'b', 'c']));
    expect(find.text('c'), findsOneWidget);

    // 数据里拿掉 'c'。
    await tester.pumpWidget(_app(['a', 'b']));
    // 让 postFrame 的 diff 跑起来。
    await tester.pump();

    // 动画进行中：离场副本还在（内容换成 leaving 版本）。
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('c (leaving)'), findsOneWidget,
        reason: '删除时该行应该保留一小会儿把高度收完，而不是瞬间抽走');

    // 动画结束后彻底消失。
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('c (leaving)'), findsNothing);
    expect(find.text('c'), findsNothing);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('新增一项：新行能正常进场', (tester) async {
    await tester.pumpWidget(_app(['a', 'b']));

    await tester.pumpWidget(_app(['x', 'a', 'b']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('x'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('大批量变化：不逐项动画，直接换成新列表', (tester) async {
    await tester.pumpWidget(_app(['a', 'b', 'c']));

    final List<String> many =
        List<String>.generate(20, (i) => 'item $i');
    await tester.pumpWidget(_app(many));
    await tester.pump();
    // 超过阈值 → 整表重建，一帧就该到位，不用等动画。
    await tester.pump();

    // 断言只挑视口内的项：AnimatedList 是懒布局的，屏幕外的压根没建 Element，
    // find 不到（不代表没进数据）。
    expect(find.text('item 0'), findsOneWidget);
    expect(find.text('item 5'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    // 整表重建 = 没有离场副本留在树里。
    expect(find.textContaining('(leaving)'), findsNothing);
  });

  testWidgets('清空再填回：列表不会崩也不会留残影', (tester) async {
    await tester.pumpWidget(_app(['a', 'b', 'c']));

    await tester.pumpWidget(_app(<String>[]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AppAnimatedList<String>), findsOneWidget);

    await tester.pumpWidget(_app(['a', 'b', 'c']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
  });
}

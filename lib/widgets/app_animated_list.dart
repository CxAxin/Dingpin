import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// 带增删过渡的列表。
///
/// 列表项突然出现 / 突然消失是最常见的「廉价感」来源：删一条通知，下面整屏
/// 内容往上跳一格；新建一条，卡片凭空塞在最上面。这里用 `AnimatedList`
/// 补上过渡——**删除时高度收起、新增时高度展开**，下面的内容是被挤开或被
/// 拉回来的，不再是瞬间跳。
///
/// 用法和 `ListView.separated` 几乎一样，只是 builder 不需要关心 index 和
/// animation：
///
/// ```dart
/// AppAnimatedList<PinnitNotification>(
///   items: visible,
///   idOf: (n) => n.uuid,
///   // 退场版本通常就是「去掉手势的同一张卡」。
///   itemBuilder: (c, n) => _buildCard(n),
///   removedItemBuilder: (c, n) => _buildRemovedCard(n),
/// )
/// ```
///
/// ## 为什么要自己维护一份列表副本
///
/// `AnimatedList` 的条目数由框架内部持有，不跟 `items.length` 自动同步：必须
/// 显式调 `insertItem` / `removeItem`，否则会崩。所以这里保存一份 `_display`
/// 副本，在 `didUpdateWidget` 里 diff 出新来的和消失的项，逐个通知列表。
///
/// ## 大批量变化不给逐项动画
///
/// 搜索过滤、清空历史这类操作一次动几十上百项，逐项动画会糊成一团（而且
/// 浪费几十个 hundredms）。超过 [_batchThreshold] 项的变化直接换掉整个列表
///（换一把新的 GlobalKey 让 AnimatedList 重新初始化），一步到位、不动画。
class AppAnimatedList<T> extends StatefulWidget {
  const AppAnimatedList({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    required this.removedItemBuilder,
    this.controller,
    this.padding,
    this.separatorHeight = 10,
  });

  /// 当前要显示的数据（通常就是 `ref.watch(...)` 出来的列表）。
  final List<T> items;

  /// 每一项的稳定唯一标识。同 id 视为同一项（数据更新不触发动画）。
  final Object Function(T item) idOf;

  /// 正常状态的一行。
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// 正在离场的一行。此时该项已经从数据里删掉了，这里渲染的多半是**去掉
  /// 手势**的同一张卡——否则 Dismissible 之类的手势控件会在收起过程中回弹。
  final Widget Function(BuildContext context, T item) removedItemBuilder;

  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  /// 条目之间的间隙。
  final double separatorHeight;

  /// 一次变化超过这么多条目就不做逐项动画（见上面的说明）。
  static const int _batchThreshold = 4;

  @override
  State<AppAnimatedList<T>> createState() => AppAnimatedListState<T>();
}

class AppAnimatedListState<T> extends State<AppAnimatedList<T>> {
  /// 操作列表（insertItem / removeItem）的把手。
  ///
  /// ⚠️ 注意：这是 `GlobalKey`，跨树"搬运"时会保留 State。想让整表重置，不能
  /// 靠给外层换 key（那样 State 会被原封不动搬到新位置，内部计数依旧是旧
  /// 的），必须像下面 [_resetTo] 那样直接换一把全新的 GlobalKey。
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  late List<T> _display = List<T>.of(widget.items);

  /// 直接换成新数据、不动画。用于大批量变化和「拿不到列表把手」的兜底。
  ///
  /// `AnimatedList` 的条目数只在初始化时读一次 `initialItemCount`，之后全靠
  /// `insertItem` / `removeItem` 维护——所以「重置」= 换把新 key 让它重新初始化。
  void _resetTo(List<T> incoming) {
    setState(() {
      _display = List<T>.of(incoming);
      _listKey = GlobalKey<AnimatedListState>();
    });
  }

  @override
  void didUpdateWidget(covariant AppAnimatedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 帧后执行：insertItem / removeItem 会触发列表自己 rebuild，在 build
    // 过程中调别的 State 的重构方法会被框架拦下来。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync();
    });
  }

  List<Object> _ids(List<T> list) => list.map(widget.idOf).toList();

  void _sync() {
    final List<T> incoming = widget.items;
    final List<Object> newIds = _ids(incoming);
    final List<Object> currentIds = _ids(_display);

    if (_sameSequence(newIds, currentIds)) return;

    final Set<Object> newIdSet = newIds.toSet();
    final Set<Object> currentIdSet = currentIds.toSet();

    // 消失的项 → 降序处理，避免前面的删除把后面的索引带偏。
    final List<int> removals = <int>[];
    for (int i = _display.length - 1; i >= 0; i--) {
      if (!newIdSet.contains(currentIds[i])) removals.add(i);
    }

    // 新来的项 → 升序插入。
    final List<MapEntry<int, T>> insertions = <MapEntry<int, T>>[];
    for (int i = 0; i < incoming.length; i++) {
      if (!currentIdSet.contains(newIds[i])) {
        insertions.add(MapEntry<int, T>(i, incoming[i]));
      }
    }

    if (removals.length + insertions.length > AppAnimatedList._batchThreshold) {
      // 太多：不要逐项动画，整表重建。
      _resetTo(incoming);
      return;
    }

    if (removals.isEmpty && insertions.isEmpty) {
      // 只是顺序变了（比如恢复一条到原位、置顶排序）——直接重排，不动画。
      setState(() => _display = List<T>.of(incoming));
      return;
    }

    final AnimatedListState? list = _listKey.currentState;
    if (list == null) {
      _resetTo(incoming);
      return;
    }

    for (final int index in removals) {
      final T removed = _display[index];
      list.removeItem(
        index,
        (BuildContext context, Animation<double> animation) =>
            _wrap(context, widget.removedItemBuilder(context, removed), animation),
        duration: AppMotion.itemOut,
      );
      _display.removeAt(index);
    }

    for (final MapEntry<int, T> entry in insertions) {
      final int index = entry.key.clamp(0, _display.length);
      _display.insert(index, entry.value);
      list.insertItem(index, duration: AppMotion.itemIn);
    }

    // 增量处理完如果顺序还是不对（少见），兜底重排一次。
    if (!_sameSequence(_ids(_display), newIds) && mounted) {
      _resetTo(incoming);
    }
  }

  bool _sameSequence(List<Object> a, List<Object> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 统一过渡：**高度展开/收起 + 淡入淡出**。
  ///
  /// 高度动画是这里的重点——只有让相邻内容平滑地让位/归位，列表才不会
  /// 「跳」。纯 transform（位移/缩放）做不到这点。
  ///
  /// 条目之间的间距挂在条目的 bottom padding 上一起收放，否则条目的高度收
  /// 到 0 了、间距还杵在那儿，会留一道坎。
  Widget _wrap(BuildContext context, Widget child, Animation<double> animation) {
    final Animation<double> curved =
        CurvedAnimation(parent: animation, curve: AppMotion.enter);
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.separatorHeight),
        child: FadeTransition(opacity: curved, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 用普通 AnimatedList 而不是 AnimatedList.separated：separated 版本把
    // 「item + 分隔」当成两条记录来增删，外部很难把索引对上（实测会漏掉条目）。
    // 间距改成由每个条目自带的 bottom padding 承担，增删就回到一对一，索引
    // 不会错位。
    return AnimatedList(
      key: _listKey,
      controller: widget.controller,
      padding: widget.padding,
      initialItemCount: _display.length,
      itemBuilder: (BuildContext context, int index, Animation<double> animation) {
        // index 由内部计数驱动，理论上永远 < _display.length；真跑偏了（罕见
        // 的竞态）就给个占位，好过崩整个列表。
        if (index >= _display.length) return const SizedBox.shrink();
        return _wrap(
          context,
          widget.itemBuilder(context, _display[index]),
          animation,
        );
      },
    );
  }
}

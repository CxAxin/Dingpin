// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '顶顶';

  @override
  String get searchNotificationsHint => '搜索通知…';

  @override
  String get toggleTheme => '切换深色 / 浅色';

  @override
  String get tooltipHistory => '通知历史';

  @override
  String get tooltipAbout => '关于';

  @override
  String copiedWithText(Object text) {
    return '已复制：$text';
  }

  @override
  String get tooltipNew => '新建通知';

  @override
  String get noMatch => '没有匹配结果';

  @override
  String get noNotifications => '还没有通知';

  @override
  String get tryAnotherKeyword => '换个关键词试试。';

  @override
  String get emptyPinHint => '点击右下角的 + 按钮，把第一条通知固定到通知栏。';

  @override
  String get cannotOpenSettings => '无法自动打开设置';

  @override
  String get manualSettingsGuide =>
      '请手动开启「通知使用权」：\n\n系统设置 → 通知与控制中心 → 通知使用权 → 找到 顶顶，打开开关。\n\n（不同小米系统版本名称略有差异，也可能在「设置 → 应用设置 → 授权管理 → 通知使用权」）';

  @override
  String get gotIt => '知道了';

  @override
  String get addNote => '添加备注';

  @override
  String get noteHint => '给这条通知写点备注…';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get copy => '复制';

  @override
  String get delete => '删除';

  @override
  String get searchHistoryHint => '搜索通知历史…';

  @override
  String get historyTitle => '通知历史';

  @override
  String get clearHistoryTitle => '清空历史？';

  @override
  String get clearHistoryBody => '这将永久删除所有已记录的通知。';

  @override
  String get clearAll => '清空';

  @override
  String get clearAllMenu => '清空全部';

  @override
  String get listenerDisabledHint => '尚未开启通知使用权。开启后才会记录其他应用的通知。';

  @override
  String get goEnable => '去开启';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(Object count) {
    return '$count 分钟前';
  }

  @override
  String hoursAgo(Object count) {
    return '$count 小时前';
  }

  @override
  String daysAgo(Object count) {
    return '$count 天前';
  }

  @override
  String get noHistory => '还没有历史记录';

  @override
  String get historyEmptyHint => '开启通知使用权后，顶顶 会把其他应用的通知记录在这里。';

  @override
  String get titleEmpty => '标题不能为空';

  @override
  String get needNotificationPermission => '需要通知权限才能固定到通知栏，请去系统设置中开启';

  @override
  String saveFailed(Object error) {
    return '保存失败：$error';
  }

  @override
  String get newNotification => '新建通知';

  @override
  String get editNotification => '编辑通知';

  @override
  String get titleLabel => '标题';

  @override
  String get contentLabel => '内容（可选）';

  @override
  String get pinToNotification => '顶到通知栏';

  @override
  String get pinSubtitle => '让它一直显示在通知栏顶部';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutSubtitle => '把重要通知固定到通知栏，随时可见。';

  @override
  String get tapToCopyAccount => '点击复制公众号名';

  @override
  String get copiedAccount => '已复制公众号：潮汕阿幸';

  @override
  String get basedOnPinnit => '基于 Pinnit 开源项目';

  @override
  String get apacheLicense => 'Apache-2.0 许可 · 二次开发';

  @override
  String get aboutFooter => '本应用基于 Apache-2.0 许可的 Pinnit 二次开发，仅供学习与交流。';

  @override
  String get notePrefix => '备注';

  @override
  String get pinAction => '顶';

  @override
  String get unpinAction => '取消顶';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get pinned => '已顶到通知栏';

  @override
  String get alreadyPinned => '已经顶过了';

  @override
  String get exportHistory => '导出';

  @override
  String get exportHistoryTitle => '顶顶通知历史';

  @override
  String get historyEmptyExport => '历史还是空的，没有可导出的内容';

  @override
  String exportFailed(Object error) {
    return '导出失败：$error';
  }

  @override
  String get exportReady => '已生成导出文件，选择应用发送即可';

  @override
  String get exportRangeHint => '选择要导出的时间范围';

  @override
  String get rangeAll => '全部';

  @override
  String get rangeDay => '一天内';

  @override
  String get rangeWeek => '一周内';

  @override
  String get rangeMonth => '一个月内';

  @override
  String get saveToLocal => '保存到本地';

  @override
  String get shareExport => '分享';

  @override
  String get ownPinLabel => '顶顶（自建）';

  @override
  String get exportSavedLocal => '已保存到「下载 / Pinnit」文件夹';

  @override
  String get exportEmptyRange => '这个时间范围内没有可导出的通知';
}

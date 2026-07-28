// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Dingpin';

  @override
  String get searchNotificationsHint => 'Search notifications…';

  @override
  String get toggleTheme => 'Toggle dark / light';

  @override
  String get tooltipHistory => 'Notification history';

  @override
  String get tooltipAbout => 'About';

  @override
  String copiedWithText(Object text) {
    return 'Copied: $text';
  }

  @override
  String get tooltipNew => 'New notification';

  @override
  String get noMatch => 'No matching results';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get tryAnotherKeyword => 'Try another keyword.';

  @override
  String get emptyPinHint =>
      'Tap the + button to pin your first notification to the notification bar.';

  @override
  String get cannotOpenSettings => 'Can\'t open settings automatically';

  @override
  String get manualSettingsGuide =>
      'Please enable Notification access manually:\n\nSettings → Notifications & control center → Notification access → find Dingpin and turn it on.\n\n(Names vary slightly across MIUI versions; it may also be under Settings → Apps → Authorization & revocation → Notification access.)';

  @override
  String get gotIt => 'Got it';

  @override
  String get addNote => 'Add note';

  @override
  String get noteHint => 'Write a note for this notification…';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get copy => 'Copy';

  @override
  String get delete => 'Delete';

  @override
  String get searchHistoryHint => 'Search history…';

  @override
  String get historyTitle => 'Notification history';

  @override
  String get clearHistoryTitle => 'Clear history?';

  @override
  String get clearHistoryBody =>
      'This permanently deletes all recorded notifications.';

  @override
  String get clearAll => 'Clear';

  @override
  String get clearAllMenu => 'Clear all';

  @override
  String get listenerDisabledHint =>
      'Notification access is not enabled. Enable it to start recording other apps\' notifications.';

  @override
  String get goEnable => 'Enable';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(Object count) {
    return '$count minutes ago';
  }

  @override
  String hoursAgo(Object count) {
    return '$count hours ago';
  }

  @override
  String daysAgo(Object count) {
    return '$count days ago';
  }

  @override
  String get noHistory => 'No history yet';

  @override
  String get historyEmptyHint =>
      'After enabling notification access, Dingpin records other apps\' notifications here.';

  @override
  String get titleEmpty => 'Title can\'t be empty';

  @override
  String get needNotificationPermission =>
      'Notification permission is required to pin to the bar. Please enable it in system settings.';

  @override
  String saveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get newNotification => 'New notification';

  @override
  String get editNotification => 'Edit notification';

  @override
  String get titleLabel => 'Title';

  @override
  String get contentLabel => 'Content (optional)';

  @override
  String get pinToNotification => 'Pin to notification bar';

  @override
  String get pinSubtitle => 'Keep it always visible in the notification bar';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutSubtitle =>
      'Pin important notifications to the bar, always visible.';

  @override
  String get tapToCopyAccount => 'Tap to copy the account name';

  @override
  String get copiedAccount => 'Copied account: Chaoshan Axing';

  @override
  String get basedOnPinnit => 'Based on the Pinnit open-source project';

  @override
  String get apacheLicense => 'Apache-2.0 license · derived work';

  @override
  String get aboutFooter =>
      'This app is a derivative work of Pinnit under Apache-2.0, for learning and exchange.';

  @override
  String get notePrefix => 'Note';

  @override
  String get pinAction => 'Pin';

  @override
  String get unpinAction => 'Unpin';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageEnglish => 'English';
}

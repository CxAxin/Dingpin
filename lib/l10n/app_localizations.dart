import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// Application name shown in the UI
  ///
  /// In en, this message translates to:
  /// **'Dingpin'**
  String get appTitle;

  /// No description provided for @searchNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Search notifications…'**
  String get searchNotificationsHint;

  /// No description provided for @toggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle dark / light'**
  String get toggleTheme;

  /// No description provided for @tooltipHistory.
  ///
  /// In en, this message translates to:
  /// **'Notification history'**
  String get tooltipHistory;

  /// No description provided for @tooltipAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get tooltipAbout;

  /// Snackbar shown after copying a notification; {text} is the copied content
  ///
  /// In en, this message translates to:
  /// **'Copied: {text}'**
  String copiedWithText(Object text);

  /// No description provided for @tooltipNew.
  ///
  /// In en, this message translates to:
  /// **'New notification'**
  String get tooltipNew;

  /// No description provided for @noMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get noMatch;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @tryAnotherKeyword.
  ///
  /// In en, this message translates to:
  /// **'Try another keyword.'**
  String get tryAnotherKeyword;

  /// No description provided for @emptyPinHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to pin your first notification to the notification bar.'**
  String get emptyPinHint;

  /// No description provided for @cannotOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open settings automatically'**
  String get cannotOpenSettings;

  /// Manual path to enable the notification listener on MIUI
  ///
  /// In en, this message translates to:
  /// **'Please enable Notification access manually:\n\nSettings → Notifications & control center → Notification access → find Dingpin and turn it on.\n\n(Names vary slightly across MIUI versions; it may also be under Settings → Apps → Authorization & revocation → Notification access.)'**
  String get manualSettingsGuide;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Write a note for this notification…'**
  String get noteHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @searchHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Search history…'**
  String get searchHistoryHint;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification history'**
  String get historyTitle;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get clearHistoryTitle;

  /// No description provided for @clearHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes all recorded notifications.'**
  String get clearHistoryBody;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearAll;

  /// No description provided for @clearAllMenu.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAllMenu;

  /// No description provided for @listenerDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Notification access is not enabled. Enable it to start recording other apps\' notifications.'**
  String get listenerDisabledHint;

  /// No description provided for @goEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get goEnable;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Relative time; {count} is the number of minutes
  ///
  /// In en, this message translates to:
  /// **'{count} minutes ago'**
  String minutesAgo(Object count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String hoursAgo(Object count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(Object count);

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistory;

  /// No description provided for @historyEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'After enabling notification access, Dingpin records other apps\' notifications here.'**
  String get historyEmptyHint;

  /// No description provided for @titleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Title can\'t be empty'**
  String get titleEmpty;

  /// No description provided for @needNotificationPermission.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is required to pin to the bar. Please enable it in system settings.'**
  String get needNotificationPermission;

  /// Save error message; {error} is the exception text
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(Object error);

  /// No description provided for @newNotification.
  ///
  /// In en, this message translates to:
  /// **'New notification'**
  String get newNotification;

  /// No description provided for @editNotification.
  ///
  /// In en, this message translates to:
  /// **'Edit notification'**
  String get editNotification;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @contentLabel.
  ///
  /// In en, this message translates to:
  /// **'Content (optional)'**
  String get contentLabel;

  /// No description provided for @pinToNotification.
  ///
  /// In en, this message translates to:
  /// **'Top to notification bar'**
  String get pinToNotification;

  /// No description provided for @pinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep it pinned at the top of the bar'**
  String get pinSubtitle;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pin important notifications to the bar, always visible.'**
  String get aboutSubtitle;

  /// No description provided for @tapToCopyAccount.
  ///
  /// In en, this message translates to:
  /// **'Tap to copy the account name'**
  String get tapToCopyAccount;

  /// No description provided for @copiedAccount.
  ///
  /// In en, this message translates to:
  /// **'Copied account: Chaoshan Axing'**
  String get copiedAccount;

  /// No description provided for @basedOnPinnit.
  ///
  /// In en, this message translates to:
  /// **'Based on the Pinnit open-source project'**
  String get basedOnPinnit;

  /// No description provided for @apacheLicense.
  ///
  /// In en, this message translates to:
  /// **'Apache-2.0 license · derived work'**
  String get apacheLicense;

  /// No description provided for @aboutFooter.
  ///
  /// In en, this message translates to:
  /// **'This app is a derivative work of Pinnit under Apache-2.0, for learning and exchange.'**
  String get aboutFooter;

  /// Prefix label before a user note on a history item
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get notePrefix;

  /// No description provided for @pinAction.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get pinAction;

  /// No description provided for @unpinAction.
  ///
  /// In en, this message translates to:
  /// **'Untop'**
  String get unpinAction;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Topped to the bar'**
  String get pinned;

  /// No description provided for @alreadyPinned.
  ///
  /// In en, this message translates to:
  /// **'Already topped'**
  String get alreadyPinned;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

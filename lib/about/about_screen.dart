// Based on Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pinnit_flutter/providers.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';
import 'package:pinnit_flutter/services/pins_bridge.dart';
import 'package:pinnit_flutter/settings/blocklist_screen.dart';
import 'package:pinnit_flutter/widgets/app_dialog.dart';
import 'package:pinnit_flutter/widgets/app_page_route.dart';
import 'package:pinnit_flutter/widgets/glass_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small "关于" page: credits the author's official account (only shown in
/// Chinese), links the upstream project, and lets the user pick a language.
/// Reachable from the main list's AppBar (info button).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const _brandAccent = Color(0xFF8A6D3B); // warm amber — matches theme
  static const _officialAccount = '潮汕阿幸';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final isChinese =
        Localizations.localeOf(context).languageCode == 'zh';
    final localeOverride = ref.watch(localeOverrideProvider);

    return Scaffold(
      // Transparent so MainScreen's gradient backing shows through; the
      // liquid-glass bottom nav needs something to read underneath it.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        // 与首页一致：透明顶栏，暖金背景直接透上来。
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.aboutTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.push_pin, size: 72, color: _brandAccent),
          const SizedBox(height: 16),
          Text(
            l10n.appTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.aboutSubtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (isChinese) ...[
                  ListTile(
                    leading: const Icon(Icons.account_circle_outlined),
                    title: const Text('by 公众号：潮汕阿幸'),
                    subtitle: Text(l10n.tapToCopyAccount),
                    trailing: const Icon(Icons.copy_outlined, size: 18),
                    onTap: () {
                      Clipboard.setData(
                        const ClipboardData(text: _officialAccount),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.copiedAccount),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: const Icon(Icons.code_outlined),
                  title: Text(l10n.basedOnPinnit),
                  subtitle: Text(l10n.apacheLicense),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              trailing: Text(_localeLabel(localeOverride, l10n)),
              onTap: () => _pickLanguage(context, ref, l10n),
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.block),
              title: Text(l10n.blocklist),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                AppPageRoute(
                  builder: (_) => const BlocklistScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.aboutFooter,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _localeLabel(Locale? override, AppLocalizations l10n) {
    if (override == null) return l10n.languageSystem;
    return override.languageCode == 'zh'
        ? l10n.languageChinese
        : l10n.languageEnglish;
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final current = ref.read(localeOverrideProvider);
    // String keys keep "follow system" distinct from "dialog dismissed":
    // dismissing returns null and changes nothing; picking "system" returns
    // 'system' and clears the override.
    final currentKey = current == null ? 'system' : current.languageCode;
    final chosenKey = await AppDialog.show<String>(
      context: context,
      icon: Icons.translate,
      title: l10n.language,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in [
            ('system', l10n.languageSystem),
            ('zh', l10n.languageChinese),
            ('en', l10n.languageEnglish),
          ])
            _LanguageOption(
              label: option.$2,
              selected: option.$1 == currentKey,
              onTap: () => Navigator.of(context).pop(option.$1),
            ),
        ],
      ),
      actions: [
        AppDialogAction<String>(
          label: l10n.cancel,
          style: AppDialogActionStyle.secondary,
        ),
      ],
    );
    if (chosenKey == null || chosenKey == currentKey) return;
    final chosen = chosenKey == 'system' ? null : Locale(chosenKey);
    ref.read(localeOverrideProvider.notifier).state = chosen;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLocalePrefKey, localePreferenceValue(chosen));
      // Pinned notifications cache the locale; drop it so the next pin shows
      // its action buttons in the new language.
      PinsBridge.instance.invalidateLocale();
    } catch (_) {
      // Ignore persistence failure; in-session override still applies.
    }
  }
}

/// 语言选择的一行：暖色填充 + 大圆角，选中时换成暖金实心圈。
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _accent = Color(0xFF8A6D3B); // warm amber — matches theme

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF2EADC);
    final textColor = isDark ? const Color(0xFFEDE4D3) : const Color(0xFF3B3226);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? _accent.withOpacity(0.14) : fill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? _accent : (isDark ? Colors.white38 : const Color(0xFFA39A89)),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: textColor,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

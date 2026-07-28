// Based on Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pinnit_flutter/providers.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small "关于" page: credits the author's official account (only shown in
/// Chinese), links the upstream project, and lets the user pick a language.
/// Reachable from the main list's AppBar (info button).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const _brandPurple = Color(0xFF6750A4);
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
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.push_pin, size: 72, color: _brandPurple),
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
          Card(
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
                const ListTile(
                  leading: Icon(Icons.code_outlined),
                  title: Text('基于 Pinnit 开源项目'),
                  subtitle: Text('Apache-2.0 许可 · 二次开发'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              trailing: Text(_localeLabel(localeOverride, l10n)),
              onTap: () => _pickLanguage(context, ref, l10n),
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
    final chosenKey = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          for (final option in [
            ('system', l10n.languageSystem),
            ('zh', l10n.languageChinese),
            ('en', l10n.languageEnglish),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(option.$1),
              child: Row(
                children: [
                  Icon(
                    option.$1 == currentKey
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: option.$1 == currentKey ? _brandPurple : null,
                  ),
                  const SizedBox(width: 12),
                  Text(option.$2),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosenKey == null || chosenKey == currentKey) return;
    final chosen = chosenKey == 'system' ? null : Locale(chosenKey);
    ref.read(localeOverrideProvider.notifier).state = chosen;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLocalePrefKey, localePreferenceValue(chosen));
    } catch (_) {
      // Ignore persistence failure; in-session override still applies.
    }
  }
}

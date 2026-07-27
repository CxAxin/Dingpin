// Based on Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A small, unobtrusive "关于" page that credits the author's official
/// account. Reachable from the main list's AppBar (info button).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _brandPurple = Color(0xFF6750A4);
  static const _officialAccount = '潮汕阿幸';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 12),
          Icon(Icons.push_pin, size: 72, color: _brandPurple),
          const SizedBox(height: 16),
          Text(
            '顶顶',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '把重要通知固定到通知栏，随时可见。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('by 公众号：潮汕阿幸'),
                  subtitle: const Text('点击复制公众号名'),
                  trailing: const Icon(Icons.copy_outlined, size: 18),
                  onTap: () {
                    Clipboard.setData(
                      const ClipboardData(text: _officialAccount),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已复制公众号：潮汕阿幸'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.code_outlined),
                  title: Text('基于 Pinnit 开源项目'),
                  subtitle: Text('Apache-2.0 许可 · 二次开发'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '本应用基于 Apache-2.0 许可的 Pinnit 二次开发，仅供学习与交流。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

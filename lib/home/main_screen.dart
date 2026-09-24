import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'package:pinnit_flutter/editor/editor_screen.dart';
import 'package:pinnit_flutter/providers.dart';
import 'package:pinnit_flutter/notifications/notifications_screen.dart';
import 'package:pinnit_flutter/notifications/history_screen.dart';
import 'package:pinnit_flutter/about/about_screen.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';
import 'package:pinnit_flutter/theme/motion.dart';
import 'package:pinnit_flutter/widgets/app_page_route.dart';
import 'package:pinnit_flutter/widgets/aurora_backdrop.dart';

/// M3 host for three tabs (自建 / 历史 / 我的).
///
/// The bottom navigation is the package's public `LiquidGlassTabBar` in
/// `withImpeller` mode: a floating glass capsule with an iOS-26-style
/// "morph pill" that slides between tabs and refracts whatever is behind
/// it (the live page contents, no captured body needed). We drop it as the
/// last child of a [Stack] over the page so it can read the live backdrop
/// on Impeller (Android) and falls back to a frosted bar on Skia/Web.
///
/// The FAB is its own refracting lens — independent of the bar.
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _index = 0;

  static const _screens = <Widget>[
    NotificationsScreen(),
    HistoryScreen(),
    AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    // A swipe-delete undo banner floats right where the FAB sits, so we tuck
    // the FAB away for the few seconds the banner is up.
    final fabParked = ref.watch(undoBannerVisibleProvider);

    return Scaffold(
      // Transparent so the glass bar reads the gradient backdrop instead
      // of a flat M3 surface. Each tab's own Scaffold is also transparent.
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Aurora backdrop ─────────────────────────────────
          // 多层径向渐变叠在一张底层 linear 渐变上：底层保证任何区域都有色
          // 彩过渡，径向层提供"极光"光斑。底部 LiquidGlassTabBar 需要这
          // 些彩色背景来折射出真正的"液态玻璃"质感。
          Positioned.fill(
            child: AuroraBackdrop(brightness: brightness),
          ),
          // ── Page content ─────────────────────────────────────
          IndexedStack(
            index: _index,
            children: _screens,
          ),
          // ── Floating glass tab bar (Impeller morph pill) ────
          // Last child so it samples the live content above it.
          LiquidGlassTabBar.withImpeller(
            items: [
              LiquidGlassTabBarItem(
                icon: Icons.push_pin_outlined,
                selectedIcon: Icons.push_pin,
                label: l10n.tabPinned,
              ),
              LiquidGlassTabBarItem(
                icon: Icons.history_outlined,
                selectedIcon: Icons.history,
                label: l10n.tabHistory,
              ),
              LiquidGlassTabBarItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: l10n.tabAbout,
              ),
            ],
            selectedIndex: _index,
            onChanged: (i) => setState(() => _index = i),
            itemStyle: LiquidGlassTabItemStyle(
              selectedColor: scheme.primary,
              unselectedColor: scheme.onSurfaceVariant,
              iconSize: 26,
            ),
            pillStyle: const LiquidGlassTabPillStyle(
              mode: LiquidGlassPillMode.impellerOnly,
              animated: true,
            ),
            width: 340,
            height: 72,
            margin: const EdgeInsets.only(bottom: 14),
          ),
          // ── FAB (its own refracting glass lens) ────────────
          if (_index == 0)
            Positioned(
              right: 24,
              bottom: 102,
              // Shifts down + fades out instead of collapsing to `scale(0)`:
              // shrinking something into nothing reads as "cheap/glitchy",
              // and the old ease-in made it *start* slow, so the button looked
              // stuck before it left. Down-and-out reads as "stepping aside"
              // for the undo bar. IgnorePointer keeps it from eating taps
              // while parked.
              child: IgnorePointer(
                ignoring: fabParked,
                child: AnimatedOpacity(
                  opacity: fabParked ? 0.0 : 1.0,
                  duration: AppMotion.itemIn,
                  curve: AppMotion.enter,
                  child: AnimatedSlide(
                    offset: fabParked ? const Offset(0, 0.6) : Offset.zero,
                    duration: AppMotion.itemIn,
                    curve: AppMotion.enter,
                    child: AnimatedScale(
                      // 永不到 0：最小 0.85，配合淡出，视觉上是"让位"。
                      scale: fabParked ? 0.85 : 1.0,
                      duration: AppMotion.itemIn,
                      curve: AppMotion.enter,
                      child: LiquidGlassLens(
                        style: const LiquidGlassStyle(
                          shape: LiquidGlassShape.squircle(cornerRadius: 28),
                        ),
                        child: FloatingActionButton(
                          heroTag: 'liquidGlassFab',
                          onPressed: () => Navigator.of(context).push(
                            AppPageRoute(builder: (_) => const EditorScreen()),
                          ),
                          tooltip: l10n.tooltipNew,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          foregroundColor: scheme.onPrimaryContainer,
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


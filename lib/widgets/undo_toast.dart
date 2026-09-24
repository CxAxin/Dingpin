import 'package:flutter/material.dart';

/// Telegram-style undo banner: a live countdown ring ticks down and the
/// banner removes itself once it reaches zero.
///
/// Why not [SnackBar]? As of Flutter 3.44 a SnackBar whose `action` is
/// non-null defaults to `persist: true` (see the `SnackBar.persist` docs:
/// "If not provided, but the snackbar action is not null, the snackbar will
/// persist as well"). That means it never auto-dismisses — it just sits on
/// screen until the app is killed, which is exactly the bug the old
/// 「已删除通知 / 撤销」bar had. This widget owns its own
/// [AnimationController], so the countdown always runs.
class UndoToast extends StatefulWidget {
  const UndoToast({
    super.key,
    required this.message,
    required this.undoLabel,
    required this.onUndo,
    required this.onDismissed,
    this.seconds = 5,
  });

  /// Human readable line, e.g. 「已删除通知」.
  final String message;

  /// Label of the undo affordance, e.g. 「撤销」.
  final String undoLabel;

  /// Fired when the user taps undo, right before the banner is removed.
  final VoidCallback onUndo;

  /// Fired once the countdown reaches zero — the action becomes permanent.
  final VoidCallback onDismissed;

  /// Countdown length in whole seconds.
  final int seconds;

  @override
  State<UndoToast> createState() => _UndoToastState();
}

class _UndoToastState extends State<UndoToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdown;

  /// Makes sure [onUndo] / [onDismissed] fire at most once even if the user
  /// taps undo during the last frame of the countdown.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.seconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _expire();
      });
    _countdown.forward();
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  void _expire() {
    if (_handled || !mounted) return;
    _handled = true;
    widget.onDismissed();
  }

  void _undo() {
    if (_handled) return;
    _handled = true;
    _countdown.stop();
    widget.onUndo();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Warm surfaces matching the app's #3B3226 / #8A6D3B palette, so the bar
    // reads on top of both the light paper backdrop and the dark one.
    final surface = isDark ? const Color(0xFF423A2E) : const Color(0xFF332C22);
    const onSurface = Color(0xFFFDFBF7);
    const accent = Color(0xFFE2B877);

    return Material(
      color: surface,
      elevation: isDark ? 6 : 8,
      shadowColor: Colors.black.withOpacity(0.4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withOpacity(0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            _CountdownRing(countdown: _countdown, accent: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: onSurface,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _undo,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: Text(widget.undoLabel),
              style: TextButton.styleFrom(
                foregroundColor: accent,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ring with the remaining seconds in the middle — the "5 → 4 → 3" chip.
///
/// The number is derived from the controller inside the [AnimatedBuilder] so
/// it rebuilds on every tick; deriving it in the parent's `build` would leave
/// it frozen at the initial value.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.countdown, required this.accent});

  final AnimationController countdown;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final total = countdown.duration?.inSeconds ?? 5;
    return SizedBox(
      width: 30,
      height: 30,
      child: AnimatedBuilder(
        animation: countdown,
        builder: (context, _) {
          final secondsLeft =
              (total * (1 - countdown.value)).ceil().clamp(1, total);
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  // Depletes clockwise as the countdown runs out.
                  value: 1 - countdown.value,
                  strokeWidth: 2.2,
                  strokeCap: StrokeCap.round,
                  color: accent,
                  backgroundColor: accent.withOpacity(0.2),
                ),
              ),
              Text(
                '$secondsLeft',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/currency_format.dart';

/// Shows the net virtual-point profit after the server settles a round.
class GameWinEffect extends StatefulWidget {
  final String roundId;
  final String status;
  final int betAmount;
  final int? credit;
  final bool revealAllowed;
  final Widget child;

  const GameWinEffect({
    super.key,
    required this.roundId,
    required this.status,
    required this.betAmount,
    required this.credit,
    this.revealAllowed = true,
    required this.child,
  });

  @override
  State<GameWinEffect> createState() => _GameWinEffectState();
}

class _GameWinEffectState extends State<GameWinEffect> {
  String? announcedRound;

  @override
  void initState() {
    super.initState();
    _announceWinIfReady();
  }

  @override
  void didUpdateWidget(covariant GameWinEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roundId != widget.roundId) announcedRound = null;
    _announceWinIfReady();
  }

  void _announceWinIfReady() {
    final credit = widget.credit;
    if (!widget.revealAllowed ||
        widget.status != 'settled' ||
        credit == null ||
        announcedRound == widget.roundId) {
      return;
    }
    final profit = credit - widget.betAmount;
    if (profit <= 0) return;

    announcedRound = widget.roundId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show(context, profit);
    });
  }

  void _show(BuildContext context, int amount) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .65, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff38200c), Color(0xff17120e)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xffffd16a), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xbfffaa24),
                      blurRadius: 34,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      color: Color(0xffffd16a),
                      size: 42,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'CHIẾN THẮNG!',
                      style: TextStyle(
                        color: Color(0xffffd16a),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '+${formatCurrencyAmount(amount)}đ',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Timer(const Duration(milliseconds: 2100), () {
      if (entry.mounted) entry.remove();
      entry.dispose();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

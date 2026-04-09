import 'package:flutter/material.dart';

import 'theme.dart';
import 'wallet_store.dart';

class WalletOverviewCard extends StatelessWidget {
  const WalletOverviewCard({
    super.key,
    required this.walletState,
    this.onTap,
  });

  final WalletState walletState;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0070FF), Color(0xFF0055E6)],
          ),
          boxShadow: appCardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
        child: Stack(
          children: [
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _WalletPatternPainter()),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Баланс',
                  style: TextStyle(fontSize: 14, color: Color(0xFFE6EBFF)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatBalance(walletState.balance)} ₸',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  walletState.activeCard?.isTransport == true
                      ? 'Транспортная'
                      : 'Стандарт',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFFD7DEFF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WalletCardsTile extends StatelessWidget {
  const WalletCardsTile({
    super.key,
    required this.walletState,
    this.onTap,
  });

  final WalletState walletState;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: walletState.cards.isEmpty
                ? const Color(0xFFD0D8E6)
                : const Color(0xFFF1F4F9),
            width: walletState.cards.isEmpty ? 2 : 1.5,
          ),
          boxShadow: walletState.cards.isEmpty
              ? const [
                  BoxShadow(
                    color: Color(0x080D1B2A),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              walletState.cards.isEmpty
                  ? Icons.add_circle_outline_rounded
                  : Icons.add_rounded,
              color: walletState.cards.isEmpty
                  ? const Color(0xFF9EA8BC)
                  : const Color(0xFFC0C7D8),
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(
              walletState.cards.isEmpty
                  ? 'Добавить\nкарту'
                  : '${walletState.cards.length}\nкарты',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w400,
                color: Color(0xFF9EA7BE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08);

    for (var row = 0; row < 6; row++) {
      for (var column = 0; column < 10; column++) {
        final left = size.width - 110 + (column * 12);
        final top = 18 + (row * 20);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left.toDouble(), top.toDouble(), 8, 3),
            const Radius.circular(100),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

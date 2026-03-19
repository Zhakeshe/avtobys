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
            colors: [Color(0xFF2E74FF), Color(0xFF1E54F5)],
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
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
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
                  style: TextStyle(fontSize: 15, color: Color(0xFFE6EBFF)),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatBalance(walletState.balance)} ₸',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  walletState.activeCard?.maskedNumber ?? 'Стандарт',
                  style: const TextStyle(
                    fontSize: 16,
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
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE4E8F0), width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFFE2E6EF)),
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.textSecondary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              walletState.cards.isEmpty
                  ? 'Добавить\nкарту'
                  : '${walletState.cards.length}\nкарты',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.2,
                color: AppColors.textSecondary,
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

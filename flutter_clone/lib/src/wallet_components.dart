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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0070FF), Color(0xFF0058E8)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x280066FF),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _WalletPatternPainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Баланс',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xE6FFFFFF),
                          ),
                        ),
                        const Spacer(),
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onTap,
                            customBorder: const CircleBorder(),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                Icons.add_rounded,
                                color: AppColors.primaryBlue,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '${formatBalance(walletState.balance)} ₸',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      walletState.activeCard?.isTransport == true
                          ? 'Транспортная'
                          : 'Стандарт',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xE6FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final empty = walletState.cards.isEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: empty ? const Color(0xFFD5DAE6) : const Color(0xFFE8ECF4),
              width: empty ? 1.5 : 1,
            ),
            boxShadow: empty
                ? const [
                    BoxShadow(
                      color: Color(0x060D1B2A),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: empty
                        ? const Color(0xFF9AA4B8)
                        : const Color(0xFFB8C0D0),
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    empty
                        ? 'Добавить карту'
                        : '${walletState.cards.length} карт${walletState.cards.length == 1 ? 'а' : 'ы'}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8E93A3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.07);

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

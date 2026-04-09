import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'l10n/app_strings.dart';
import 'theme.dart';
import 'transport_overlays.dart';
import 'wallet_store.dart';

/// Фон сканера — не чистый чёрный, чтобы экран не выглядел «заваленным».
const Color _kScannerScaffoldBg = Color(0xFF2C3544);

/// Full-screen QR scanner (reference UI) then [TransportPaymentOverlay] after a read.
class QrScanPaymentScreen extends StatefulWidget {
  const QrScanPaymentScreen({
    super.key,
    required this.phoneNumber,
    required this.cityName,
    required this.walletState,
    required this.rideAccessEnabled,
    required this.trialRidesRemaining,
    required this.accessTelegram,
    required this.onBack,
    required this.onSessionRefresh,
    required this.allowSecureCameraContext,
    this.uiStrings,
  });

  final String phoneNumber;
  final String cityName;
  final WalletState walletState;
  final bool rideAccessEnabled;
  final int trialRidesRemaining;
  final String accessTelegram;
  final VoidCallback onBack;
  final RefreshSessionCallback onSessionRefresh;

  /// Web: camera needs HTTPS or localhost.
  final bool allowSecureCameraContext;

  final AppStrings? uiStrings;

  @override
  State<QrScanPaymentScreen> createState() => _QrScanPaymentScreenState();
}

class _QrScanPaymentScreenState extends State<QrScanPaymentScreen> {
  String? _scannedToken;
  MobileScannerController? _scannerController;
  final TextEditingController _manualController = TextEditingController();
  bool _manualMode = false;
  bool _torchOn = false;

  WalletCardData? get _transportCard {
    for (final card in widget.walletState.cards) {
      if (card.id == widget.walletState.activeCardId && card.isTransport) {
        return card;
      }
    }
    for (final card in widget.walletState.cards) {
      if (card.isTransport) {
        return card;
      }
    }
    return null;
  }

  bool get _scannerPlatformSupported {
    if (kIsWeb) {
      return widget.allowSecureCameraContext;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (!_scannerPlatformSupported) {
      _manualMode = true;
    } else {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _applyScannedCode(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || !mounted) {
      return;
    }
    await _scannerController?.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _scannedToken = code;
    });
  }

  void _backToScanner() {
    setState(() {
      _scannedToken = null;
    });
    if (_scannerController != null && !_manualMode) {
      unawaited(_scannerController!.start());
    }
  }

  Future<void> _toggleTorch() async {
    final c = _scannerController;
    if (c == null) {
      return;
    }
    await c.toggleTorch();
    if (mounted) {
      setState(() {
        _torchOn = !_torchOn;
      });
    }
  }

  void _submitManual() {
    _applyScannedCode(_manualController.text);
  }

  @override
  Widget build(BuildContext context) {
    if (_scannedToken != null) {
      return TransportPaymentOverlay(
        mode: TransportSearchMode.qr,
        phoneNumber: widget.phoneNumber,
        cityName: widget.cityName,
        walletState: widget.walletState,
        rideAccessEnabled: widget.rideAccessEnabled,
        trialRidesRemaining: widget.trialRidesRemaining,
        accessTelegram: widget.accessTelegram,
        onBack: _backToScanner,
        onSessionRefresh: widget.onSessionRefresh,
        initialQrToken: _scannedToken,
        uiStrings: widget.uiStrings,
      );
    }

    final phone = formatPhoneForWalletBanner(widget.phoneNumber);
    final tariff = walletBannerTariffSubtitle(_transportCard);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _kScannerScaffoldBg,
        body: _manualMode
            ? _ManualQrFallback(
                phoneNumber: phone,
                tariffLabel: tariff,
                balance: widget.walletState.balance,
                controller: _manualController,
                onSubmit: _submitManual,
                onClose: widget.onBack,
                insecureWeb: kIsWeb && !widget.allowSecureCameraContext,
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  final side = (size.shortestSide * 0.72).clamp(200.0, 320.0);
                  final cutOut = Rect.fromCenter(
                    center: size.center(Offset.zero),
                    width: side,
                    height: side,
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: MobileScanner(
                        controller: _scannerController,
                        fit: BoxFit.cover,
                        placeholderBuilder: (context) => const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 18),
                              Text(
                                'Подключение камеры…',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'Разрешите доступ к камере в запросе браузера',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        errorBuilder: (context, error) {
                          return ColoredBox(
                            color: _kScannerScaffoldBg,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      error.errorDetails?.message ?? error.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _manualMode = true;
                                        });
                                      },
                                      child: const Text(
                                        'Ввести QR token вручную',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        onDetect: (capture) {
                          for (final b in capture.barcodes) {
                            final v = b.rawValue ?? b.displayValue;
                            if (v != null && v.trim().isNotEmpty) {
                              unawaited(_applyScannedCode(v));
                              return;
                            }
                          }
                        },
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _ScannerDimPainter(cutOut: cutOut),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      Positioned(
                        left: cutOut.left,
                        top: cutOut.top,
                        width: cutOut.width,
                        height: cutOut.height,
                        child: const _PulsingCornerBrackets(),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: cutOut.bottom + 16,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0x33000000)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Наведите камеру на QR-код',
                                  style: TextStyle(
                                    color: Color(0xFF1A1F2A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Держите устройство ровно, пока код в рамке',
                                  style: TextStyle(
                                    color: Color(0xFF5C6478),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: _QrWalletBottomBar(
                              phone: phone,
                              tariff: tariff,
                              balance: widget.walletState.balance,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                _ScannerCircleIconButton(
                                  icon: _torchOn
                                      ? Icons.flash_on_rounded
                                      : Icons.flash_off_rounded,
                                  onPressed: _toggleTorch,
                                  tooltip: 'Вспышка',
                                ),
                                const Spacer(),
                                _ScannerCircleIconButton(
                                  icon: Icons.close_rounded,
                                  onPressed: widget.onBack,
                                  tooltip: 'Закрыть',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// Круглая кнопка поверх превью: хорошо видна на тёмной маске (как в референсе).
class _ScannerCircleIconButton extends StatelessWidget {
  const _ScannerCircleIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

class _PulsingCornerBrackets extends StatefulWidget {
  const _PulsingCornerBrackets();

  @override
  State<_PulsingCornerBrackets> createState() => _PulsingCornerBracketsState();
}

class _PulsingCornerBracketsState extends State<_PulsingCornerBrackets>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.82, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: const _CornerBrackets(),
    );
  }
}

class _ScannerDimPainter extends CustomPainter {
  _ScannerDimPainter({required this.cutOut});

  final Rect cutOut;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(RRect.fromRectAndRadius(cutOut, const Radius.circular(4)));
    final overlay = Path.combine(PathOperation.difference, full, hole);
    // Сине-серая вуаль вместо плотного чёрного — видно превью камеры (особенно в web).
    canvas.drawPath(
      overlay,
      Paint()..color = const Color(0x992C354B),
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerDimPainter oldDelegate) {
    return oldDelegate.cutOut != cutOut;
  }
}

class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF5B7CFF);
    const t = 3.0;
    const len = 28.0;
    Widget corner({required Alignment a, required bool top, required bool left}) {
      return Align(
        alignment: a,
        child: SizedBox(
          width: len,
          height: len,
          child: CustomPaint(
            painter: _LCornerPainter(
              color: color,
              strokeWidth: t,
              top: top,
              left: left,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(a: Alignment.topLeft, top: true, left: true),
        corner(a: Alignment.topRight, top: true, left: false),
        corner(a: Alignment.bottomLeft, top: false, left: true),
        corner(a: Alignment.bottomRight, top: false, left: false),
      ],
    );
  }
}

class _LCornerPainter extends CustomPainter {
  _LCornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.top,
    required this.left,
  });

  final Color color;
  final double strokeWidth;
  final bool top;
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    if (top && left) {
      canvas.drawLine(Offset.zero, Offset(w, 0), paint);
      canvas.drawLine(Offset.zero, Offset(0, h), paint);
    } else if (top && !left) {
      canvas.drawLine(Offset(w, 0), Offset(0, 0), paint);
      canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
    } else if (!top && left) {
      canvas.drawLine(Offset(0, h), Offset(0, 0), paint);
      canvas.drawLine(Offset(0, h), Offset(w, h), paint);
    } else {
      canvas.drawLine(Offset(w, h), Offset(0, h), paint);
      canvas.drawLine(Offset(w, h), Offset(w, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LCornerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.top != top ||
        oldDelegate.left != left;
  }
}

class _QrWalletBottomBar extends StatelessWidget {
  const _QrWalletBottomBar({
    required this.phone,
    required this.tariff,
    required this.balance,
  });

  final String phone;
  final String tariff;
  final double balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Кошелек',
                  style: TextStyle(
                    color: Color(0xFF1A1F2A),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  phone,
                  style: const TextStyle(color: Color(0xFF2A3142), fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  tariff,
                  style: const TextStyle(color: Color(0xFF6B7289), fontSize: 14),
                ),
              ],
            ),
          ),
          Text(
            '${formatBalance(balance)} ₸',
            style: const TextStyle(
              color: Color(0xFF0066FF),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualQrFallback extends StatelessWidget {
  const _ManualQrFallback({
    required this.phoneNumber,
    required this.tariffLabel,
    required this.balance,
    required this.controller,
    required this.onSubmit,
    required this.onClose,
    required this.insecureWeb,
  });

  final String phoneNumber;
  final String tariffLabel;
  final double balance;
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onClose;
  final bool insecureWeb;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _ScannerCircleIconButton(
                icon: Icons.close_rounded,
                onPressed: onClose,
                tooltip: 'Закрыть',
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (insecureWeb)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Камера в браузере доступна только по HTTPS или на localhost. '
                      'Введите QR token вручную или откройте сайт по защищённому адресу.',
                      style: TextStyle(color: Colors.white, height: 1.35),
                    ),
                  )
                else
                  const Text(
                    'Камера недоступна на этой платформе. Введите QR token автобуса.',
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                const SizedBox(height: 20),
                _QrWalletBottomBar(
                  phone: phoneNumber,
                  tariff: tariffLabel,
                  balance: balance,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'QR token автобуса',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textCapitalization: TextCapitalization.none,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Найти автобус по QR token'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

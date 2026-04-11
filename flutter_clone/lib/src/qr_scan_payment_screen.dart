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

/// Референс: төменгі «Кошелек» панелі (қою көк-сұр).
const Color _kQrWalletCardBg = Color(0xFF3E4B5E);

/// Сканер бұрыштары (жарқыраған көк).
const Color _kQrCornerBlue = Color(0xFF2F7CF6);

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_ensureCameraStarted());
      });
    }
  }

  /// Web / iOS PWA: виджет салынғаннан кейін камераны显式 қосу керек.
  Future<void> _ensureCameraStarted() async {
    final c = _scannerController;
    if (!mounted || c == null || _manualMode) {
      return;
    }
    try {
      await c.start();
    } catch (_) {
      if (mounted) {
        setState(() {
          _manualMode = true;
        });
      }
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
      unawaited(_ensureCameraStarted());
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
                controller: _manualController,
                onSubmit: _submitManual,
                onClose: widget.onBack,
                insecureWeb: kIsWeb && !widget.allowSecureCameraContext,
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  final side = (size.shortestSide * 0.70).clamp(208.0, 312.0);
                  final cutOut = Rect.fromCenter(
                    center: size.center(Offset(0, -size.height * 0.04)),
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
                                  padding: EdgeInsets.symmetric(horizontal: 28),
                                  child: Text(
                                    'Разрешите доступ к камере. В PWA откройте настройки сайта, если запрос не появился.',
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
                                        error.errorDetails?.message ??
                                            error.toString(),
                                        textAlign: TextAlign.center,
                                        style:
                                            const TextStyle(color: Colors.white70),
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
                        child: const _CornerBrackets(),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: cutOut.bottom + 14,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.48),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Text(
                              'Наведите камеру на QR-код',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
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
              color: Colors.black.withValues(alpha: 0.35),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

class _ScannerDimPainter extends CustomPainter {
  _ScannerDimPainter({required this.cutOut});

  final Rect cutOut;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRect(cutOut);
    final overlay = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.52),
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
    const color = _kQrCornerBlue;
    const t = 4.0;
    const len = 40.0;
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
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      decoration: BoxDecoration(
        color: _kQrWalletCardBg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Кошелек',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${formatBalance(balance)} ₸',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                phone,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tariff,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualQrFallback extends StatelessWidget {
  const _ManualQrFallback({
    required this.controller,
    required this.onSubmit,
    required this.onClose,
    required this.insecureWeb,
  });

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
              'Камера недоступна или не запустилась. Введите QR token автобуса.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
          const SizedBox(height: 20),
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

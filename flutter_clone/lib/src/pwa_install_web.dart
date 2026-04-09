import 'dart:js_interop';

@JS('avtobysTriggerPwaInstall')
external JSFunction? get _avtobysTriggerPwaInstall;

Future<bool> triggerPwaInstallPrompt() async {
  final fn = _avtobysTriggerPwaInstall;
  if (fn == null) {
    return false;
  }
  try {
    final raw = fn.callAsFunction();
    final out = await (raw as JSPromise<JSAny?>).toDart;
    if (out == null) {
      return false;
    }
    final s = out.toString();
    return s == 'true' || s == '1';
  } catch (_) {
    return false;
  }
}

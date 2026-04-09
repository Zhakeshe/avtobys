import 'dart:js_interop';

@JS('avtobysRequestBluetoothDevice')
external JSFunction? get _avtobysRequestBluetoothDevice;

Future<String?> pickBluetoothDeviceLabelWeb() async {
  final fn = _avtobysRequestBluetoothDevice;
  if (fn == null) {
    return null;
  }
  try {
    final promise = fn.callAsFunction();
    final value = await (promise as JSPromise<JSAny?>).toDart;
    if (value == null) {
      return null;
    }
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  } catch (_) {
    return null;
  }
}

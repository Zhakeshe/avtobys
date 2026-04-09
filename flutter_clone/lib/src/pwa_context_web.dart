import 'package:web/web.dart';

bool get isPwaStandaloneMode {
  final w = window;
  if (w.matchMedia('(display-mode: standalone)').matches) {
    return true;
  }
  if (w.matchMedia('(display-mode: fullscreen)').matches) {
    return true;
  }
  if (w.matchMedia('(display-mode: minimal-ui)').matches) {
    return true;
  }
  return false;
}

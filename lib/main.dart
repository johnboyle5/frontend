import 'package:flutter/widgets.dart';

import 'package:soliplex_frontend/soliplex_frontend.dart';
import 'package:soliplex_frontend/flavors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final callbackParams = CallbackParamsCapture.captureNow();
  clearCallbackUrl();
  runSoliplexShell(await standard(callbackParams: callbackParams));
}

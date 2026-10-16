import 'package:flutter/foundation.dart';

// A single web bundle works both behind the local proxy and on the production host.
bool get useBrowserOrigin =>
    kIsWeb && const bool.fromEnvironment('CAMPULSE_WEB_SAME_ORIGIN');
String browserEndpoint(String path, String configured) => useBrowserOrigin
    ? Uri.base.resolve(path).toString().replaceAll(RegExp(r'/$'), '')
    : configured;

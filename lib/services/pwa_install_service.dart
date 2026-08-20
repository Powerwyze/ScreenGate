// Handles PWA install prompts (Add to Home Screen) with web-only implementation.
import 'package:screengate/services/pwa_install_service_stub.dart'
    if (dart.library.html) 'package:screengate/services/pwa_install_service_web.dart'
    as impl;

/// Sets up the event listener for the browser's `beforeinstallprompt` event.
void initPwaInstallPrompt() => impl.initPwaInstallPrompt();

/// Returns true when the browser has an install prompt available.
bool canShowPwaInstallPrompt() => impl.canShowPwaInstallPrompt();

/// Returns a user-friendly blocker message when the prompt cannot be shown.
String? getPwaInstallBlocker() => impl.getPwaInstallBlocker();

/// Triggers the install prompt if available. Returns true when the user accepts.
Future<bool> showPwaInstallPrompt() => impl.showPwaInstallPrompt();

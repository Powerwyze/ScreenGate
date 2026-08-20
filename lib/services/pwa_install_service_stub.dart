// Stub implementation for non-web platforms.
void initPwaInstallPrompt() {}

bool canShowPwaInstallPrompt() => false;

String? getPwaInstallBlocker() =>
    'Add to Home Screen is only available in supported browsers.';

Future<bool> showPwaInstallPrompt() async => false;

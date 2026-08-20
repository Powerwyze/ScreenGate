void initPwaInstallPrompt() {}

bool canShowPwaInstallPrompt() => false;

String? getPwaInstallBlocker() {
  return 'Use your browser menu to install ScreenGate when installation is available.';
}

Future<bool> showPwaInstallPrompt() async => false;

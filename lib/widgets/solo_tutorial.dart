import 'package:flutter/material.dart';

Future<void> showSoloTutorial(BuildContext context,
    {bool firstRun = false}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: !firstRun,
    builder: (_) => const _SoloTutorialDialog(),
  );
}

Future<void> showSoloHelper(BuildContext context) async {
  await showSoloTutorial(context);
}

class _SoloTutorialDialog extends StatefulWidget {
  const _SoloTutorialDialog();

  @override
  State<_SoloTutorialDialog> createState() => _SoloTutorialDialogState();
}

class _SoloTutorialDialogState extends State<_SoloTutorialDialog> {
  final _controller = PageController();
  int _page = 0;

  static const _steps = [
    (
      'Welcome to Solo',
      'AI is your only approver. No parent phone, family code, or family approval is needed.'
    ),
    (
      '1. Choose a task',
      'Create a focus task or choose one from your list. Make the goal small and clear.'
    ),
    (
      '2. Submit proof',
      'When you finish, submit the proof requested by the task. Be honest and specific.'
    ),
    (
      '3. AI reviews',
      'The AI helper checks your proof and approves or asks you to try again.'
    ),
    (
      '4. Earn your outcome',
      'Approved tasks unlock your configured reward or screen-time allowance.'
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _steps.length - 1;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C63FF)),
          const SizedBox(width: 10),
          Expanded(child: Text(_steps[_page].$1)),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 130,
              child: PageView.builder(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (_, index) => Text(_steps[index].$2,
                    style: const TextStyle(fontSize: 16, height: 1.45)),
              ),
            ),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    _steps.length,
                    (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == _page
                                ? const Color(0xFF6C63FF)
                                : Colors.black26)))),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(last ? 'Done' : 'Skip')),
        if (!last)
          FilledButton(
              onPressed: () => _controller.nextPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut),
              child: const Text('Next')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class CloseAppScope extends StatefulWidget {
  const CloseAppScope({super.key, required this.child, this.onInterceptBack});

  final Widget child;
  final bool Function()? onInterceptBack;

  @override
  State<CloseAppScope> createState() => _CloseAppScopeState();
}

class _CloseAppScopeState extends State<CloseAppScope> {
  bool _promptOpen = false;

  Future<void> _onPopInvoked(bool didPop) async {
    if (didPop || _promptOpen) {
      return;
    }
    if (widget.onInterceptBack?.call() == true) {
      return;
    }
    _promptOpen = true;
    final shouldClose = await confirmClosePeam(context);
    _promptOpen = false;
    if (shouldClose && context.mounted) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        _onPopInvoked(didPop);
      },
      child: widget.child,
    );
  }
}

Future<bool> confirmClosePeam(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Close PEAM?'),
        content: const Text(
          'You can open the app again from your home screen.',
        ),
        actions: [
          TextButton(
            key: const Key('close-app-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            key: const Key('close-app-confirm'),
            style: TextButton.styleFrom(foregroundColor: AppColors.ink),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
  return result == true;
}

import 'package:flutter/material.dart';

/// Feedback rápido de sucesso/erro no rodapé da tela.
void showAppSnackBar(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: error ? TextStyle(color: scheme.onErrorContainer) : null,
        ),
        backgroundColor: error ? scheme.errorContainer : null,
      ),
    );
}

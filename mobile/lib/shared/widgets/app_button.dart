import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

enum AppButtonVariant { primary, secondary }

/// Botão padrão do app, com estado de carregamento (fica desabilitado enquanto carrega).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.variant = AppButtonVariant.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final AppButtonVariant variant;

  /// Ocupa toda a largura disponível (padrão em formulários).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final callback = loading ? null : onPressed;
    final child = AnimatedSwitcher(
      duration: AppDurations.fast,
      child: loading
          ? Semantics(
              key: const ValueKey('loading'),
              label: '$label: carregando',
              child: const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          : Text(label, key: const ValueKey('label')),
    );
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(onPressed: callback, child: child),
      AppButtonVariant.secondary =>
        OutlinedButton(onPressed: callback, child: child),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

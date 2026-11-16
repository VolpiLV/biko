import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'app_button.dart';

/// Estado "Aguardando" padrão.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (text != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(text, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// Estado "Erro" padrão: mensagem amigável + "Tentar novamente".
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retry = onRetry;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          if (retry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Tentar novamente',
              onPressed: retry,
              variant: AppButtonVariant.secondary,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}

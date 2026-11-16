import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/state_views.dart';
import '../viewmodels/session_view_model.dart';

/// Primeira tela: aguarda a verificação do token salvo.
/// Se não houver conexão, mostra o erro com "Tentar novamente".
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final failed = session.status == SessionStatus.failed;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 72),
                const SizedBox(height: AppSpacing.xl),
                AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: failed
                      ? ErrorView(
                          key: const ValueKey('error'),
                          message: session.errorMessage ??
                              'Não foi possível verificar sua sessão.',
                          onRetry: session.restore,
                        )
                      : const LoadingView(
                          key: ValueKey('loading'),
                          message: 'Carregando...',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

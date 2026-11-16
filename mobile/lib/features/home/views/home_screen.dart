import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/role_badge.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../settings/widgets/theme_mode_button.dart';

/// Tela inicial após o login. Por enquanto mostra os dados reais da conta logada;
/// os atalhos de cada perfil (busca, pedidos, gestão) entram nas próximas etapas.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final session = context.read<SessionViewModel>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sair da conta?',
      message: 'Você precisará entrar novamente para usar o app.',
      confirmLabel: 'Sair',
    );
    if (confirmed) await session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<SessionViewModel, UserModel?>((s) => s.user);
    // Durante a troca de rota após o logout o usuário já é nulo por um instante.
    if (user == null) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${user.firstName}'),
        actions: [
          const ThemeModeButton(),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [_AccountCard(user: user)],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final phone = user.phone;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(user: user),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(user.email, style: textTheme.bodyMedium),
                  if (phone != null && phone.isNotEmpty)
                    Text(phone, style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  RoleBadge(role: user.role),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

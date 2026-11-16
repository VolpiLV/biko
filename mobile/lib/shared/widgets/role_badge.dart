import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/biko_colors.dart';
import '../../data/models/user_role.dart';

/// Selo com o perfil do usuário (Admin / Cliente / Prestador).
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.bikoColors;
    final (background, foreground) = switch (role) {
      UserRole.admin => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      UserRole.cliente => (scheme.primaryContainer, scheme.onPrimaryContainer),
      UserRole.prestador => (brand.highlight, brand.onHighlight),
    };
    return Semantics(
      label: 'Perfil: ${role.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          role.label,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

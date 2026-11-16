import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/biko_colors.dart';

/// Marca do Biko: selo azul com o "b" e o nome ao lado.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Biko',
      header: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(size * 0.3),
            ),
            child: Text(
              'b',
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: size * 0.6,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          SizedBox(width: size * 0.25),
          Text(
            'Biko',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: size * 0.55,
              fontWeight: FontWeight.w800,
            ),
          ),
          Container(
            width: size * 0.14,
            height: size * 0.14,
            margin: const EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.md),
            decoration: BoxDecoration(
              color: context.bikoColors.highlight,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

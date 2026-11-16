import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Moldura das telas de formulário: rolagem com teclado aberto, área segura,
/// largura máxima em telas grandes/paisagem e centralização vertical quando cabe.
class FormPage extends StatelessWidget {
  const FormPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0.0, constraints.maxHeight - AppSpacing.lg * 2),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.formMaxWidth,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

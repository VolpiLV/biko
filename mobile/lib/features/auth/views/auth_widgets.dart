import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/biko_colors.dart';
import '../../../shared/widgets/biko_ui.dart';

/// Campo das telas de entrada: rótulo em cima e ícone dentro (como no Figma).
/// Com [obscure] vira campo de senha com botão de mostrar/ocultar.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.labelTrailing,
    this.hint,
    this.icon,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final Widget? labelTrailing;
  final String? hint;
  final IconData? icon;
  final FormFieldValidator<String>? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(widget.label, trailing: widget.labelTrailing),
          TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            validator: widget.validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            obscureText: widget.obscure && _hidden,
            autocorrect: !widget.obscure,
            enableSuggestions: !widget.obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            enabled: widget.enabled,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 20),
              suffixIcon: widget.obscure
                  ? IconButton(
                      tooltip: _hidden ? 'Mostrar senha' : 'Ocultar senha',
                      icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : null,
            ),
          ),
        ],
      );
}

/// "biko" grande abaixo do logo.
class BrandName extends StatelessWidget {
  const BrandName({super.key});

  @override
  Widget build(BuildContext context) => Text(
        'biko',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 34, letterSpacing: -1, color: context.bikoColors.ink),
      );
}

/// Cartão branco das telas do prestador (`.auth-card`).
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

/// "—— OU CONTINUE COM ——"
class OrDivider extends StatelessWidget {
  const OrDivider(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 18),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(text, style: TextStyle(color: c.muted2, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
          ),
          Expanded(child: Divider(color: c.line)),
        ],
      ),
    );
  }
}

/// Botão "Google"/"Apple" (só visual nesta versão).
class SocialButton extends StatelessWidget {
  const SocialButton({super.key, required this.label, required this.google, required this.onPressed});

  final String label;
  final bool google;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (google)
              const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w800, fontSize: 18))
            else
              Icon(Icons.apple, color: c.ink, size: 22),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// Topo das telas de cadastro: "← Título" e os passos (bolinhas).
class AuthTopBar extends StatelessWidget {
  const AuthTopBar({super.key, required this.title, this.step, this.total});

  final String title;
  final int? step;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          const BackButton(),
          Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text))),
          if (total case final t?)
            Row(
              children: [
                for (var i = 1; i <= t; i++)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    width: i == step ? 22 : 9,
                    height: 9,
                    decoration: BoxDecoration(color: i == step ? c.blue : c.line, borderRadius: BorderRadius.circular(9)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_tokens.dart';

/// Campo de formulário padrão. Com [obscure] vira campo de senha com botão de mostrar/ocultar.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.hint,
    this.helperText,
    this.prefixIcon,
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
  final FormFieldValidator<String>? validator;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
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
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final icon = widget.prefixIcon;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
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
          labelText: widget.label,
          hintText: widget.hint,
          helperText: widget.helperText,
          helperMaxLines: 2,
          prefixIcon: icon == null ? null : Icon(icon),
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: _hidden ? 'Mostrar senha' : 'Ocultar senha',
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ),
      ),
    );
  }
}

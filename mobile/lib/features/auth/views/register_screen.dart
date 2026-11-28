import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/phone_input_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/user_role.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/error_banner.dart';
import '../viewmodels/register_view_model.dart';
import 'auth_widgets.dart';

/// Cadastro do cliente. Com dados digitados, voltar pede confirmação.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _dirty = false;

  late final List<TextEditingController> _controllers = [
    _nameController,
    _emailController,
    _phoneController,
    _passwordController,
    _confirmController,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Só reconstrói quando o estado "tem alterações" muda (não a cada tecla).
  void _updateDirty() {
    final dirty = _controllers.any((c) => c.text.isNotEmpty);
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  Future<void> _confirmLeave() async {
    final leave = await showConfirmDialog(
      context,
      title: 'Descartar cadastro?',
      message: 'Os dados que você preencheu serão perdidos.',
      confirmLabel: 'Descartar',
      cancelLabel: 'Continuar editando',
      destructive: true,
    );
    // Navigator.pop ignora o PopScope (diferente do maybePop do botão voltar).
    if (leave && mounted) Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final created = await context.read<RegisterViewModel>().submit(
          RegisterInput(
            name: _nameController.text,
            email: _emailController.text,
            phone: _phoneController.text,
            password: _passwordController.text,
            role: UserRole.cliente,
          ),
        );
    // Erros por campo vindos do servidor (ex.: e-mail já cadastrado) aparecem no próprio campo.
    if (!created && mounted) _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RegisterViewModel>();
    final c = context.bikoColors;
    final enabled = !vm.loading;
    String? withServerError(String field, String? localError) => localError ?? vm.fieldError(field);

    return PopScope<Object?>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: c.card,
        appBar: AppBar(backgroundColor: c.card, centerTitle: false, title: const Text('Criar conta')),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(26, 4, 26, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    onChanged: _updateDirty,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Crie sua conta', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.ink)),
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 4),
                          child: Text(
                            'Encontre profissionais perto de você e agende em poucos toques.',
                            style: TextStyle(color: c.muted),
                          ),
                        ),
                        if (vm.errorMessage case final message?) ...[const SizedBox(height: 12), ErrorBanner(message: message)],
                        AuthField(
                          controller: _nameController,
                          label: 'Nome completo',
                          hint: 'Seu nome',
                          icon: Icons.person_outline,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          enabled: enabled,
                          onChanged: (_) => vm.clearFieldError('name'),
                          validator: (v) => withServerError('name', Validators.name(v)),
                        ),
                        AuthField(
                          controller: _emailController,
                          label: 'E-mail',
                          hint: 'exemplo@email.com',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          enabled: enabled,
                          onChanged: (_) => vm.clearFieldError('email'),
                          validator: (v) => withServerError('email', Validators.email(v)),
                        ),
                        AuthField(
                          controller: _phoneController,
                          label: 'Telefone',
                          hint: '(47) 99999-9999',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          inputFormatters: [PhoneInputFormatter()],
                          enabled: enabled,
                          onChanged: (_) => vm.clearFieldError('phone'),
                          validator: (v) => withServerError('phone', Validators.optionalPhone(v)),
                        ),
                        AuthField(
                          controller: _passwordController,
                          label: 'Senha',
                          hint: 'Mín. 8 caracteres, letras e números',
                          icon: Icons.lock_outline,
                          obscure: true,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          enabled: enabled,
                          onChanged: (_) => vm.clearFieldError('password'),
                          validator: (v) => withServerError('password', Validators.newPassword(v)),
                        ),
                        AuthField(
                          controller: _confirmController,
                          label: 'Confirmar senha',
                          icon: Icons.lock_outline,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          enabled: enabled,
                          validator: Validators.confirmPassword(() => _passwordController.text),
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 22),
                        BikoButton(label: 'Criar conta', trailingIcon: Icons.arrow_forward, loading: vm.loading, onPressed: _submit),
                        const SizedBox(height: 22),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('Já tem conta? ', style: TextStyle(color: c.muted, fontSize: 13.5)),
                            LinkText('Entrar', size: 14, onTap: () => Navigator.of(context).maybePop()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

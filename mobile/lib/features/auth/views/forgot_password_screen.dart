import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/form_page.dart';
import '../viewmodels/forgot_password_view_model.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vm = context.read<ForgotPasswordViewModel>();
    await vm.requestCode(_email.text);
    if (vm.devToken case final token?) _code.text = token;
  }

  void _continue() {
    final vm = context.read<ForgotPasswordViewModel>();
    if (vm.devToken case final token?) _code.text = token;
    vm.goToReset();
  }

  Future<void> _reset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final message = await context.read<ForgotPasswordViewModel>().reset(
          token: _code.text,
          password: _password.text,
        );
    if (!mounted || message == null) return;
    showAppSnackBar(context, message);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ForgotPasswordViewModel>();
    final theme = Theme.of(context);
    final enabled = !vm.loading;
    final isEmail = vm.step == ForgotStep.email;

    return Scaffold(
      appBar: AppBar(title: Text(isEmail ? 'Recuperar senha' : 'Nova senha')),
      body: FormPage(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormError(vm.errorMessage),
              if (isEmail) ...[
                Text('Informe o e-mail da sua conta para receber o código.', style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _email,
                  label: 'E-mail',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  enabled: enabled,
                  validator: Validators.email,
                  onFieldSubmitted: (_) => _requestCode(),
                ),
                if (vm.info case final info?) ...[
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(info, style: TextStyle(color: theme.colorScheme.onSecondaryContainer)),
                          if (vm.devToken case final token?) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Modo demonstração (em produção iria por e-mail). Seu código:',
                              style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                            ),
                            SelectableText(
                              token,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(label: 'Continuar', onPressed: _continue),
                ] else
                  AppButton(label: 'Enviar código', loading: vm.loading, onPressed: _requestCode),
                const SizedBox(height: AppSpacing.sm),
                TextButton(onPressed: enabled ? vm.goToReset : null, child: const Text('Já tenho um código')),
              ] else ...[
                AppTextField(
                  controller: _code,
                  label: 'Código de recuperação',
                  prefixIcon: Icons.pin_outlined,
                  enabled: enabled,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o código.' : null,
                ),
                AppTextField(
                  controller: _password,
                  label: 'Nova senha',
                  helperText: 'Mínimo de 8 caracteres, com letras e números.',
                  prefixIcon: Icons.lock_outline,
                  obscure: true,
                  enabled: enabled,
                  validator: Validators.newPassword,
                ),
                AppTextField(
                  controller: _confirm,
                  label: 'Confirmar nova senha',
                  prefixIcon: Icons.lock_outline,
                  obscure: true,
                  enabled: enabled,
                  validator: Validators.confirmPassword(() => _password.text),
                  onFieldSubmitted: (_) => _reset(),
                ),
                AppButton(label: 'Redefinir senha', loading: vm.loading, onPressed: _reset),
                const SizedBox(height: AppSpacing.sm),
                TextButton(onPressed: enabled ? vm.backToEmail : null, child: const Text('Pedir um novo código')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/form_page.dart';
import '../viewmodels/login_view_model.dart';
import '../viewmodels/session_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Ex.: "Sua sessão expirou" — mostrado depois do primeiro frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notice = context.read<SessionViewModel>().takeNotice();
      if (notice != null) showAppSnackBar(context, notice);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<LoginViewModel>().submit(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: FormPage(
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AppLogo()),
                const SizedBox(height: AppSpacing.xl),
                Text('Entre na sua conta', style: textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Encontre profissionais ou ofereça seus serviços.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (vm.errorMessage case final message?) ...[
                  ErrorBanner(message: message),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppTextField(
                  controller: _emailController,
                  label: 'E-mail',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  enabled: !vm.loading,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                AppTextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  label: 'Senha',
                  prefixIcon: Icons.lock_outline,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: Validators.loginPassword,
                  enabled: !vm.loading,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(label: 'Entrar', loading: vm.loading, onPressed: _submit),
                Center(
                  child: TextButton(
                    onPressed: vm.loading ? null : () => context.push(AppRoutes.forgot),
                    child: const Text('Esqueci a senha'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Ainda não tem conta?'),
                    TextButton(
                      onPressed: vm.loading
                          ? null
                          : () => context.push(AppRoutes.register),
                      child: const Text('Criar conta'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Demo: admin@biko.com / Admin@123\n'
                  'cliente@biko.com / Cliente@123\n'
                  'prestador@biko.com / Prestador@123',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/error_banner.dart';
import '../viewmodels/login_view_model.dart';
import '../viewmodels/session_view_model.dart';
import 'auth_widgets.dart';

/// Login (telas "Usua 1" e "Prest 1" do Figma). Entra com e-mail ou telefone.
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

  /// "Área do Prestador": mesmo login, outro visual e outro cadastro.
  bool _provider = false;

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
    await context.read<LoginViewModel>().submit(email: _emailController.text, password: _passwordController.text);
  }

  void _social(String name) =>
      showAppSnackBar(context, 'Entrar com $name ainda não está disponível nesta versão. Use e-mail ou telefone.');

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    final c = context.bikoColors;
    final p = _provider;

    final form = AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (vm.errorMessage case final message?) ...[const SizedBox(height: 12), ErrorBanner(message: message)],
            AuthField(
              controller: _emailController,
              label: 'E-mail ou Telefone',
              hint: p ? 'carlos.silva@biko.com.br' : 'cliente@biko.com.br',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              validator: Validators.loginId,
              enabled: !vm.loading,
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            AuthField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              label: 'Senha',
              labelTrailing: LinkText('Esqueceu?', onTap: vm.loading ? null : () => context.push(AppRoutes.forgot)),
              hint: '••••••••',
              icon: Icons.lock_outline,
              obscure: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: Validators.loginPassword,
              enabled: !vm.loading,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 22),
            BikoButton(label: p ? 'Entrar na Conta' : 'Entrar', trailingIcon: Icons.arrow_forward, loading: vm.loading, onPressed: _submit),
            const OrDivider('OU CONTINUE COM'),
            if (p) ...[
              SocialButton(label: 'Entrar com Google', google: true, onPressed: () => _social('Google')),
              const SizedBox(height: 12),
              SocialButton(label: 'Entrar com Apple', google: false, onPressed: () => _social('Apple')),
            ] else
              ButtonPair(
                left: SocialButton(label: 'Google', google: true, onPressed: () => _social('Google')),
                right: SocialButton(label: 'Apple', google: false, onPressed: () => _social('Apple')),
              ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: p ? c.background : c.card,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(26, p ? 40 : 54, 26, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BikoLogoMark()),
                  const SizedBox(height: 10),
                  const BrandName(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                    child: Text(
                      p ? 'Trabalhe onde e quando quiser' : 'O serviço que você precisa, no preço\ne tempo que você pode.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted, fontSize: 14, height: 1.5),
                    ),
                  ),
                  if (p) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: c.orangeSoft, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '💼 ÁREA DO PRESTADOR',
                          style: TextStyle(color: c.orangeText, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    AuthCard(child: form),
                  ] else
                    form,
                  const SizedBox(height: 18),
                  if (!p)
                    Center(
                      child: LinkText(
                        '💼 Sou profissional · Área do Prestador',
                        onTap: vm.loading ? null : () => setState(() => _provider = true),
                      ),
                    ),
                  const SizedBox(height: 22),
                  if (!p) Divider(color: c.line),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(p ? 'Ainda não oferece seus serviços? ' : 'Não tem uma conta? ', style: TextStyle(color: c.muted, fontSize: 13.5)),
                      LinkText(
                        p ? 'Cadastre-se como Profissional' : 'Cadastre-se',
                        size: 14,
                        onTap: vm.loading ? null : () => context.push(p ? AppRoutes.registerPro : AppRoutes.register),
                      ),
                    ],
                  ),
                  if (p)
                    Center(
                      child: LinkText('← Sou cliente', color: c.muted, onTap: vm.loading ? null : () => setState(() => _provider = false)),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    'Contas de teste: cliente@biko.com / Cliente@123 · prestador@biko.com / Prestador@123\n'
                    'joana@biko.com / Joana@123 · admin@biko.com / Admin@123',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.muted, fontSize: 12, height: 1.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

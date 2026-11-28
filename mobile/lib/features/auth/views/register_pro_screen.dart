import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/phone_input_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/user_role.dart';
import '../../../data/remote/auth_service.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/error_banner.dart';
import '../viewmodels/register_view_model.dart';
import 'auth_widgets.dart';

/// Cadastro do profissional (tela "Prest 2"), em 2 passos:
/// 1) Verificação do Profissional: nome, CPF, nascimento (18+) e termos.
/// 2) Dados de acesso: e-mail, telefone e senha.
class RegisterProScreen extends StatefulWidget {
  const RegisterProScreen({super.key});

  @override
  State<RegisterProScreen> createState() => _RegisterProScreenState();
}

class _RegisterProScreenState extends State<RegisterProScreen> {
  final _step1 = GlobalKey<FormState>();
  final _step2 = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cpf = TextEditingController();
  final _birth = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _terms = false;
  String? _termsError;
  int _step = 1;

  late final List<TextEditingController> _all = [_name, _cpf, _birth, _email, _phone, _password, _confirm];

  bool get _dirty => _terms || _all.any((c) => c.text.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _birth.addListener(() => setState(() {})); // mostra a idade enquanto digita
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _back() async {
    if (_step == 2) {
      setState(() => _step = 1);
      return;
    }
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showConfirmDialog(
      context,
      title: 'Descartar cadastro?',
      message: 'Os dados que você preencheu serão perdidos.',
      confirmLabel: 'Descartar',
      cancelLabel: 'Continuar editando',
      destructive: true,
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  void _next() {
    final ok = _step1.currentState?.validate() ?? false;
    setState(() => _termsError = _terms ? null : 'Aceite os Termos do Prestador para continuar.');
    if (ok && _terms) setState(() => _step = 2);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_step2.currentState?.validate() ?? false)) return;
    final vm = context.read<RegisterViewModel>();
    final created = await vm.submit(
      RegisterInput(
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
        role: UserRole.prestador,
        professional: ProfessionalCheck(cpf: _cpf.text, birthDate: _birth.text, terms: _terms),
      ),
    );
    if (!mounted) return;
    if (created) {
      showAppSnackBar(context, 'Cadastro verificado! Agora cadastre seus serviços no Perfil.');
      return;
    }
    // Problema na verificação (CPF, idade, termos): volta para o passo 1.
    if (['cpf', 'birth_date', 'terms'].any((f) => vm.fieldError(f) != null)) {
      setState(() => _step = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) => _step1.currentState?.validate());
      if (vm.errorMessage case final msg?) showAppSnackBar(context, msg, error: true);
    } else {
      _step2.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RegisterViewModel>();
    final c = context.bikoColors;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 12, 26, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTopBar(title: _step == 1 ? 'Identificação' : 'Acesso', step: _step, total: 3),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _step == 1 ? _verification(c, vm) : _access(c, vm),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _verification(BikoColors c, RegisterViewModel vm) {
    final age = Validators.ageOf(_birth.text);
    String? server(String f, String? local) => local ?? vm.fieldError(f);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Verificação do Profissional', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.ink)),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Precisamos do seu CPF para validar seu cadastro e garantir a segurança do app.',
            style: TextStyle(color: c.muted, height: 1.5),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.blueSoft,
            border: Border.all(color: c.blue.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: c.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Requisito Biko: ', style: TextStyle(fontWeight: FontWeight.w700, color: c.blue)),
                    const TextSpan(
                      text: 'Apenas pessoas maiores de 18 anos podem prestar serviços na plataforma. Seus dados estão protegidos pela LGPD.',
                    ),
                  ]),
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        AuthCard(
          child: Form(
            key: _step1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthField(
                  controller: _name,
                  label: 'Nome Completo',
                  hint: 'Seu nome completo',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (v) => server('name', Validators.name(v)),
                  onChanged: (_) => vm.clearFieldError('name'),
                ),
                AuthField(
                  controller: _cpf,
                  label: 'CPF (Apenas números)',
                  hint: '000.000.000-00',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [_MaskFormatter(Fmt.cpf)],
                  validator: (v) => server('cpf', Validators.cpf(v)),
                  onChanged: (_) => vm.clearFieldError('cpf'),
                ),
                AuthField(
                  controller: _birth,
                  label: 'Data de Nascimento',
                  hint: 'DD/MM/AAAA',
                  icon: Icons.calendar_today_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_MaskFormatter(Fmt.birth)],
                  validator: (v) => server('birth_date', Validators.birthDate(v)),
                  onChanged: (_) => vm.clearFieldError('birth_date'),
                ),
                if (age != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: age >= 18
                        ? Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: c.green, size: 18),
                              const SizedBox(width: 6),
                              Text('Maioridade confirmada ($age anos).', style: TextStyle(color: c.green, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          )
                        : Text('Menor de 18 anos: não é possível prestar serviços.', style: TextStyle(color: c.danger, fontSize: 12)),
                  ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setState(() {
                    _terms = !_terms;
                    if (_terms) _termsError = null;
                  }),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _terms,
                        onChanged: (v) => setState(() {
                          _terms = v ?? false;
                          if (_terms) _termsError = null;
                        }),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text.rich(
                            TextSpan(children: [
                              const TextSpan(text: 'Declaro que os dados pertencem a mim e aceito os '),
                              TextSpan(text: 'Termos do Prestador', style: TextStyle(fontWeight: FontWeight.w700, color: c.blue)),
                              const TextSpan(text: '.'),
                            ]),
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_termsError ?? vm.fieldError('terms') case final e?)
                  Text(e, style: TextStyle(color: c.danger, fontSize: 12)),
                const SizedBox(height: 20),
                BikoButton(label: 'Validar e Continuar', trailingIcon: Icons.arrow_forward, onPressed: _next),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Para testar: CPF 529.982.247-25',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Já tem conta? ', style: TextStyle(color: c.muted, fontSize: 13.5)),
            LinkText('Entrar', size: 14, onTap: _back),
          ],
        ),
      ],
    );
  }

  Widget _access(BikoColors c, RegisterViewModel vm) {
    String? server(String f, String? local) => local ?? vm.fieldError(f);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Dados de acesso', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.ink)),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 16),
          child: Text('Com eles você entra no app e recebe os chamados.', style: TextStyle(color: c.muted)),
        ),
        AuthCard(
          child: AutofillGroup(
            child: Form(
              key: _step2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (vm.errorMessage case final message?) ...[const SizedBox(height: 12), ErrorBanner(message: message)],
                  AuthField(
                    controller: _email,
                    label: 'E-mail',
                    hint: 'voce@email.com',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    enabled: !vm.loading,
                    onChanged: (_) => vm.clearFieldError('email'),
                    validator: (v) => server('email', Validators.email(v)),
                  ),
                  AuthField(
                    controller: _phone,
                    label: 'Telefone',
                    hint: '(47) 99999-9999',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [PhoneInputFormatter()],
                    enabled: !vm.loading,
                    onChanged: (_) => vm.clearFieldError('phone'),
                    validator: (v) => server('phone', Validators.optionalPhone(v)),
                  ),
                  AuthField(
                    controller: _password,
                    label: 'Senha',
                    hint: 'Mín. 8 caracteres, letras e números',
                    icon: Icons.lock_outline,
                    obscure: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    enabled: !vm.loading,
                    onChanged: (_) => vm.clearFieldError('password'),
                    validator: (v) => server('password', Validators.newPassword(v)),
                  ),
                  AuthField(
                    controller: _confirm,
                    label: 'Confirmar senha',
                    icon: Icons.lock_outline,
                    obscure: true,
                    enabled: !vm.loading,
                    validator: Validators.confirmPassword(() => _password.text),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  BikoButton(label: 'Criar conta profissional', trailingIcon: Icons.arrow_forward, loading: vm.loading, onPressed: _submit),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Aplica uma máscara (CPF, data) a cada tecla, deixando o cursor no fim.
class _MaskFormatter extends TextInputFormatter {
  _MaskFormatter(this.mask);

  final String Function(String) mask;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = mask(newValue.text);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

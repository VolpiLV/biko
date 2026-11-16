import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/phone_input_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/user_role.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/form_page.dart';
import '../viewmodels/register_view_model.dart';

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
  UserRole _role = UserRole.cliente;
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

  bool get _hasChanges =>
      _role != UserRole.cliente || _controllers.any((c) => c.text.isNotEmpty);

  /// Só reconstrói quando o estado "tem alterações" muda (não a cada tecla).
  void _updateDirty() {
    final dirty = _hasChanges;
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
    final vm = context.read<RegisterViewModel>();
    final created = await vm.submit(
      RegisterInput(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
        role: _role,
      ),
    );
    // Erros por campo vindos do servidor (ex.: e-mail já cadastrado) aparecem no próprio campo.
    if (!created && mounted) _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RegisterViewModel>();
    final textTheme = Theme.of(context).textTheme;
    final enabled = !vm.loading;

    String? withServerError(String field, String? localError) =>
        localError ?? vm.fieldError(field);

    return PopScope<Object?>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Criar conta')),
        body: FormPage(
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              onChanged: _updateDirty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Você quer contratar ou prestar serviços?',
                      style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<UserRole>(
                    segments: [
                      for (final role in const [UserRole.cliente, UserRole.prestador])
                        ButtonSegment(value: role, label: Text(role.label)),
                    ],
                    selected: {_role},
                    onSelectionChanged: enabled
                        ? (selection) {
                            setState(() => _role = selection.first);
                            _updateDirty();
                          }
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (vm.errorMessage case final message?) ...[
                    ErrorBanner(message: message),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppTextField(
                    controller: _nameController,
                    label: 'Nome completo',
                    prefixIcon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    enabled: enabled,
                    onChanged: (_) => vm.clearFieldError('name'),
                    validator: (v) => withServerError('name', Validators.name(v)),
                  ),
                  AppTextField(
                    controller: _emailController,
                    label: 'E-mail',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    enabled: enabled,
                    onChanged: (_) => vm.clearFieldError('email'),
                    validator: (v) =>
                        withServerError('email', Validators.email(v)),
                  ),
                  AppTextField(
                    controller: _phoneController,
                    label: 'Telefone (opcional)',
                    hint: '(47) 99999-0000',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [PhoneInputFormatter()],
                    enabled: enabled,
                    onChanged: (_) => vm.clearFieldError('phone'),
                    validator: (v) =>
                        withServerError('phone', Validators.optionalPhone(v)),
                  ),
                  AppTextField(
                    controller: _passwordController,
                    label: 'Senha',
                    helperText: 'Mínimo de 8 caracteres, com letras e números.',
                    prefixIcon: Icons.lock_outline,
                    obscure: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    enabled: enabled,
                    onChanged: (_) => vm.clearFieldError('password'),
                    validator: (v) =>
                        withServerError('password', Validators.newPassword(v)),
                  ),
                  AppTextField(
                    controller: _confirmController,
                    label: 'Confirmar senha',
                    prefixIcon: Icons.lock_outline,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    enabled: enabled,
                    validator:
                        Validators.confirmPassword(() => _passwordController.text),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Criar conta',
                    loading: vm.loading,
                    onPressed: _submit,
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

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/phone_input_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_role.dart';
import '../../../data/remote/profile_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../home/app_navigator.dart';
import '../../payments/views/sales_tab.dart';
import '../../settings/viewmodels/theme_view_model.dart';
import '../viewmodels/account_view_models.dart';

/// "Minha Conta" em tela própria (cliente abre pelo topo do Início; prestador pela engrenagem do Perfil).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: bikoAppBar(context, 'Minha Conta'),
        body: const AccountTab(withTitle: false),
      );
}

/// "Minha Conta": foto, meus dados, alterar senha, tema e sair.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key, this.withTitle = true});

  final bool withTitle;

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfileService>();
    final session = context.read<SessionViewModel>();
    final user = context.select<SessionViewModel, UserModel?>((s) => s.user);
    if (user == null) return const SizedBox.shrink();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PhotoViewModel(service, session)),
        ChangeNotifierProvider(create: (_) => ProfileFormViewModel(service, session)),
        ChangeNotifierProvider(create: (_) => PasswordFormViewModel(service)),
      ],
      child: BikoPage(
        children: [
          if (withTitle) const PageTitle('Minha Conta') else const SizedBox(height: 10),
          _PhotoSection(user: user),
          _Section(title: 'Meus dados', child: _ProfileForm(user: user)),
          const _Section(title: 'Alterar senha', child: _PasswordForm()),
          const _Section(title: 'Aparência', child: _ThemePicker()),
          if (user.role == UserRole.cliente)
            BikoCard(
              onTap: () => pushScreen<void>(context, const PaymentsScreen()),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: context.bikoColors.greenSoft, borderRadius: BorderRadius.circular(14)),
                    child: const Text('🧾', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Meus pagamentos', style: TextStyle(fontWeight: FontWeight.w700, color: context.bikoColors.ink)),
                        Text('Comprovantes e estornos', style: TextStyle(color: context.bikoColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.bikoColors.muted),
                ],
              ),
            ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.page), child: _LogoutButton()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => BikoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [CardTitle(title), child],
        ),
      );
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.user});

  final UserModel user;

  Future<void> _pick(BuildContext context) async {
    final vm = context.read<PhotoViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    // Reduz para 256x256 no próprio aparelho/navegador: a foto fica bem abaixo do limite de 200 KB.
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final error = await vm.upload(bytes);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error ?? 'Foto atualizada.')));
  }

  Future<void> _remove(BuildContext context) async {
    final vm = context.read<PhotoViewModel>();
    final error = await vm.remove();
    if (context.mounted) showAppSnackBar(context, error ?? 'Foto removida.', error: error != null);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PhotoViewModel>();
    final c = context.bikoColors;
    final tone = switch (user.role) {
      UserRole.prestador => TagTone.orange,
      UserRole.admin => TagTone.purple,
      UserRole.cliente => TagTone.blue,
    };
    return BikoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              BikoAvatar(name: user.name, photoUrl: user.photoUrl, size: 92, ring: true),
              if (vm.busy) const CircularProgressIndicator(),
            ],
          ),
          const SizedBox(height: 12),
          Text(user.name, textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.ink)),
          Text(user.email, style: TextStyle(color: c.muted, fontSize: 13.5)),
          const SizedBox(height: 10),
          Tag(user.role.label, tone: tone),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BikoButton(
                label: user.photoUrl == null ? 'Adicionar foto' : 'Trocar foto',
                style: BikoButtonStyle.light,
                small: true,
                expand: false,
                onPressed: vm.busy ? null : () => _pick(context),
              ),
              if (user.photoUrl != null) LinkText('Remover', color: c.danger, onTap: vm.busy ? null : () => _remove(context)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.user});

  final UserModel user;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _email = TextEditingController(text: widget.user.email);
  late final _phone = TextEditingController(text: widget.user.phone);
  final _current = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _current.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vm = context.read<ProfileFormViewModel>();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await vm.save(
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
      currentPassword: _current.text,
    );
    if (!mounted) return;
    if (ok) {
      _current.clear();
      showAppSnackBar(context, 'Dados atualizados.');
    } else {
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileFormViewModel>();
    final enabled = !vm.loading;
    final changingEmail = vm.emailChanged(_email.text);
    String? server(String field, String? local) => local ?? vm.fieldError(field);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormError(vm.errorMessage),
          AppTextField(
            controller: _name,
            label: 'Nome completo',
            prefixIcon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            enabled: enabled,
            onChanged: (_) => vm.clearFieldError('name'),
            validator: (v) => server('name', Validators.name(v)),
          ),
          AppTextField(
            controller: _email,
            label: 'E-mail',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            enabled: enabled,
            onChanged: (_) {
              vm.clearFieldError('email');
              setState(() {}); // mostra/esconde o campo de senha atual
            },
            validator: (v) => server('email', Validators.email(v)),
          ),
          AppTextField(
            controller: _phone,
            label: 'Telefone (opcional)',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [PhoneInputFormatter()],
            enabled: enabled,
            onChanged: (_) => vm.clearFieldError('phone'),
            validator: (v) => server('phone', Validators.optionalPhone(v)),
          ),
          if (changingEmail)
            AppTextField(
              controller: _current,
              label: 'Senha atual (necessária para trocar o e-mail)',
              prefixIcon: Icons.lock_outline,
              obscure: true,
              enabled: enabled,
              onChanged: (_) => vm.clearFieldError('currentPassword'),
              validator: (v) => server(
                'currentPassword',
                (v ?? '').isEmpty ? 'Informe a senha atual para trocar o e-mail.' : null,
              ),
            ),
          AppButton(label: 'Salvar alterações', loading: vm.loading, onPressed: _submit),
        ],
      ),
    );
  }
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm();

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vm = context.read<PasswordFormViewModel>();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final message = await vm.change(current: _current.text, next: _next.text);
    if (!mounted) return;
    if (message != null) {
      _current.clear();
      _next.clear();
      _confirm.clear();
      _formKey.currentState?.reset();
      showAppSnackBar(context, message);
    } else {
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PasswordFormViewModel>();
    final enabled = !vm.loading;
    String? server(String field, String? local) => local ?? vm.fieldError(field);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormError(vm.errorMessage),
          AppTextField(
            controller: _current,
            label: 'Senha atual',
            prefixIcon: Icons.lock_outline,
            obscure: true,
            enabled: enabled,
            onChanged: (_) => vm.clearFieldError('currentPassword'),
            validator: (v) => server('currentPassword', Validators.loginPassword(v)),
          ),
          AppTextField(
            controller: _next,
            label: 'Nova senha',
            helperText: 'Mínimo de 8 caracteres, com letras e números.',
            prefixIcon: Icons.lock_reset_outlined,
            obscure: true,
            enabled: enabled,
            onChanged: (_) => vm.clearFieldError('newPassword'),
            validator: (v) => server('newPassword', Validators.newPassword(v)),
          ),
          AppTextField(
            controller: _confirm,
            label: 'Confirmar nova senha',
            prefixIcon: Icons.lock_reset_outlined,
            obscure: true,
            enabled: enabled,
            validator: Validators.confirmPassword(() => _next.text),
            onFieldSubmitted: (_) => _submit(),
          ),
          AppButton(label: 'Alterar senha', loading: vm.loading, onPressed: _submit),
        ],
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    final mode = context.select<ThemeViewModel, ThemeMode>((vm) => vm.mode);
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode_outlined)),
        ButtonSegment(value: ThemeMode.dark, label: Text('Escuro'), icon: Icon(Icons.dark_mode_outlined)),
        ButtonSegment(value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.brightness_auto_outlined)),
      ],
      selected: {mode},
      onSelectionChanged: (s) => context.read<ThemeViewModel>().setMode(s.first),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  Future<void> _confirm(BuildContext context) async {
    final session = context.read<SessionViewModel>();
    final ok = await showConfirmDialog(
      context,
      title: 'Sair da conta?',
      message: 'Você precisará entrar novamente para usar o app.',
      confirmLabel: 'Sair',
      destructive: true,
    );
    if (ok) await session.signOut();
  }

  @override
  Widget build(BuildContext context) => BikoButton(
        label: 'Sair da conta',
        icon: Icons.logout,
        style: BikoButtonStyle.outline,
        foreground: context.bikoColors.danger,
        onPressed: () => _confirm(context),
      );
}

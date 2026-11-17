import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/phone_input_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/user_model.dart';
import '../../../data/remote/profile_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/role_badge.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../settings/viewmodels/theme_view_model.dart';
import '../viewmodels/account_view_models.dart';

/// Aba "Conta": foto, meus dados, alterar senha, tema e sair.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

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
      child: TabPage(
        children: [
          _PhotoSection(user: user),
          const SizedBox(height: AppSpacing.md),
          _Section(title: 'Meus dados', child: _ProfileForm(user: user)),
          const _Section(title: 'Alterar senha', child: _PasswordForm()),
          const _Section(title: 'Aparência', child: _ThemePicker()),
          const SizedBox(height: AppSpacing.sm),
          const _LogoutButton(),
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
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
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
    final theme = Theme.of(context);
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            UserAvatar(user: user, radius: 44),
            if (vm.busy) const CircularProgressIndicator(),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              RoleBadge(role: user.role),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: vm.busy ? null : () => _pick(context),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(user.photoUrl == null ? 'Adicionar foto' : 'Trocar foto'),
                  ),
                  if (user.photoUrl != null)
                    TextButton(
                      onPressed: vm.busy ? null : () => _remove(context),
                      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                      child: const Text('Remover'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
      onPressed: () => _confirm(context),
      icon: const Icon(Icons.logout),
      label: const Text('Sair da conta'),
    );
  }
}

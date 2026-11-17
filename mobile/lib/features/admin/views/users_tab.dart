import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/phone_input_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_role.dart';
import '../../../data/remote/admin_service.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/role_badge.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../viewmodels/users_view_model.dart';

/// Aba "Usuários" (somente admin).
class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  late final UsersViewModel _vm = context.read<UsersViewModel>();
  late final TextEditingController _search = TextEditingController(text: _vm.filters.search);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _vm.refresh();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm([UserModel? user]) async {
    final service = context.read<AdminService>();
    final session = context.read<SessionViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showAppSheet<UserModel>(
      context,
      (_) => ChangeNotifierProvider(
        create: (_) => UserFormViewModel(service, editing: user, currentUserId: session.user?.id ?? 0),
        child: const _UserForm(),
      ),
    );
    if (saved == null) return;
    if (saved.id == session.user?.id) session.updateUser(saved);
    messenger.showSnackBar(SnackBar(content: Text(user == null ? 'Usuário criado.' : 'Alterações salvas.')));
    await _vm.refresh();
  }

  Future<void> _loadMore() async {
    await _vm.loadMore();
    if (!mounted) return;
    if (_vm.takeLoadMoreError() case final msg?) showAppSnackBar(context, msg, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UsersViewModel>();
    final f = vm.filters;
    return TabPage(
      onRefresh: vm.refresh,
      children: [
        TextField(
          controller: _search,
          decoration: const InputDecoration(hintText: 'Buscar por nome ou e-mail', prefixIcon: Icon(Icons.search)),
          onChanged: vm.setSearch,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<UserRole?>(
                initialValue: f.role,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Perfil'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos os perfis')),
                  for (final r in UserRole.values) DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: vm.setRole,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: DropdownButtonFormField<bool?>(
                initialValue: f.active,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Qualquer status')),
                  DropdownMenuItem(value: true, child: Text('Ativos')),
                  DropdownMenuItem(value: false, child: Text('Desativados')),
                ],
                onChanged: vm.setActive,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Novo usuário'),
          ),
        ),
        if (vm.loading && !vm.loaded)
          const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView())
        else if (vm.errorMessage case final msg? when vm.items.isEmpty)
          Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: ErrorView(message: msg, onRetry: vm.refresh))
        else ...[
          if (vm.loading) const LinearProgressIndicator(),
          CountLabel('${vm.total} usuário(s)'),
          if (vm.items.isEmpty)
            const EmptyView(icon: Icons.person_search_outlined, message: 'Nenhum resultado encontrado.')
          else
            for (final u in vm.items)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  leading: UserAvatar(user: u, radius: 22),
                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.email),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          RoleBadge(role: u.role),
                          Pill.active(context, active: u.active, off: 'Desativado'),
                        ],
                      ),
                    ],
                  ),
                  trailing: TextButton(onPressed: () => _openForm(u), child: const Text('Editar')),
                  onTap: () => _openForm(u),
                ),
              ),
          LoadMoreButton(visible: vm.hasMore, loading: vm.loadingMore, onPressed: _loadMore),
        ],
      ],
    );
  }
}

class _UserForm extends StatefulWidget {
  const _UserForm();

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  late final UserFormViewModel _vm = context.read<UserFormViewModel>();
  late final _name = TextEditingController(text: _vm.editing?.name);
  late final _email = TextEditingController(text: _vm.editing?.email);
  late final _phone = TextEditingController(text: _vm.editing?.phone);
  final _password = TextEditingController();
  late UserRole _role = _vm.editing?.role ?? UserRole.cliente;
  late bool _active = _vm.editing?.active ?? true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await _vm.save(
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
      role: _role,
      active: _active,
      password: _password.text,
    );
    if (!mounted) return;
    if (saved != null) {
      Navigator.of(context).pop(saved);
    } else {
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserFormViewModel>();
    final enabled = !vm.loading;
    String? server(String field, String? local) => local ?? vm.fieldError(field);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: vm.isNew ? 'Novo usuário' : 'Editar usuário'),
          FormError(vm.errorMessage),
          AppTextField(
            controller: _name,
            label: 'Nome completo',
            prefixIcon: Icons.person_outline,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => vm.clearFieldError('name'),
            validator: (v) => server('name', Validators.name(v)),
          ),
          AppTextField(
            controller: _email,
            label: 'E-mail',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            enabled: enabled,
            onChanged: (_) => vm.clearFieldError('email'),
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
          DropdownButtonFormField<UserRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Perfil', prefixIcon: Icon(Icons.badge_outlined)),
            items: [
              for (final r in const [UserRole.cliente, UserRole.prestador, UserRole.admin])
                DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: enabled && !vm.isSelf ? (v) => setState(() => _role = v ?? _role) : null,
            validator: (_) => vm.fieldError('role'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (vm.isNew)
            AppTextField(
              controller: _password,
              label: 'Senha inicial',
              helperText: 'Mínimo de 8 caracteres, com letras e números.',
              prefixIcon: Icons.lock_outline,
              obscure: true,
              enabled: enabled,
              onChanged: (_) => vm.clearFieldError('password'),
              validator: (v) => server('password', Validators.newPassword(v)),
            )
          else
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Conta ativa'),
              subtitle: const Text('Desativados não conseguem entrar'),
              value: _active,
              onChanged: enabled && !vm.isSelf ? (v) => setState(() => _active = v) : null,
            ),
          if (vm.isSelf)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Você não pode desativar nem alterar o perfil da sua própria conta.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          FormActions(submitLabel: 'Salvar', loading: vm.loading, onSubmit: _submit),
        ],
      ),
    );
  }
}

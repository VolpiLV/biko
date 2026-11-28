import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/remote/catalog_service.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../viewmodels/my_services_view_model.dart';

/// Aba "Serviços" do prestador.
class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MyServicesViewModel>().load();
    });
  }

  Future<void> _openForm([ServiceModel? service]) async {
    final vm = context.read<MyServicesViewModel>();
    final catalog = context.read<CatalogService>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showAppSheet<ServiceModel>(
      context,
      (_) => ChangeNotifierProvider(
        create: (_) => ServiceFormViewModel(catalog, editing: service),
        child: _ServiceForm(categories: vm.categories),
      ),
    );
    if (saved == null) return;
    messenger.showSnackBar(SnackBar(content: Text(service == null ? 'Serviço cadastrado.' : 'Serviço atualizado.')));
    await vm.load();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MyServicesViewModel>();
    final c = context.bikoColors;
    return BikoPage(
      onRefresh: vm.load,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: BikoButton(label: 'Novo serviço', icon: Icons.add, onPressed: vm.loaded ? () => _openForm() : null),
        ),
        if (vm.loading && !vm.loaded)
          const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView())
        else if (vm.errorMessage case final msg? when !vm.loaded)
          Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: ErrorView(message: msg, onRetry: vm.load))
        else if (vm.services.isEmpty)
          const EmptyText('Você ainda não cadastrou serviços.\nCadastre um para aparecer na busca dos clientes.')
        else
          for (final s in vm.services)
            BikoCard(
              onTap: () => _openForm(s),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${CategoryStyle.emojiOf(s.category)} ${s.title}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: c.ink),
                        ),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '${s.category} · ${Fmt.duration(s.durationMin)} · '),
                            TextSpan(text: Fmt.brl(s.price), style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
                          ]),
                          style: TextStyle(color: c.muted, fontSize: 12.5),
                        ),
                        if (s.realStats case final r? when r.count > 0 && r.medianMin != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: 'Tempo real típico: ${Fmt.duration(r.medianMin!)} (${r.count} atendimento(s))'),
                                if (r.suggestedMin != null && r.suggestedMin != s.durationMin)
                                  TextSpan(
                                    text: ' · sugestão: ${Fmt.duration(r.suggestedMin!)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: r.suggestedMin! < s.durationMin ? c.green : const Color(0xFFC2410C),
                                    ),
                                  ),
                              ]),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Tag(s.active ? 'Ativo' : 'Inativo', tone: s.active ? TagTone.green : TagTone.gray),
                      LinkText('Editar', onTap: () => _openForm(s)),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _ServiceForm extends StatefulWidget {
  const _ServiceForm({required this.categories});

  final List<CategoryModel> categories;

  @override
  State<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<_ServiceForm> {
  final _formKey = GlobalKey<FormState>();
  late final ServiceFormViewModel _vm = context.read<ServiceFormViewModel>();
  late final _title = TextEditingController(text: _vm.editing?.title);
  late final _description = TextEditingController(text: _vm.editing?.description);
  late final _price = TextEditingController(
    text: _vm.editing == null ? '' : _vm.editing!.price.toStringAsFixed(2).replaceAll('.', ','),
  );
  late String _category = _vm.editing?.category ??
      (widget.categories.isNotEmpty ? widget.categories.first.name : '');
  late int _duration = _vm.editing?.durationMin ?? 60;
  late bool _active = _vm.editing?.active ?? true;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await _vm.save(
      ServiceInput(
        title: _title.text,
        category: _category,
        description: _description.text,
        price: Fmt.parseMoney(_price.text) ?? 0,
        durationMin: _duration,
        active: _vm.isNew ? null : _active,
      ),
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
    final vm = context.watch<ServiceFormViewModel>();
    final enabled = !vm.loading;
    final durations = {...ServiceFormViewModel.durations, _duration}.toList()..sort();
    final categories = {for (final c in widget.categories) c.name, if (_category.isNotEmpty) _category};

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: vm.isNew ? 'Novo serviço' : 'Editar serviço'),
          FormError(vm.errorMessage),
          TextFormField(
            controller: _title,
            maxLength: 80,
            enabled: enabled,
            decoration: const InputDecoration(labelText: 'Título', hintText: 'Ex.: Troca de torneira'),
            onChanged: (_) => vm.clearFieldError('title'),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.length < 3 || t.length > 80) return 'O título deve ter de 3 a 80 caracteres.';
              return vm.fieldError('title');
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _category.isEmpty ? null : _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: enabled ? (v) => setState(() => _category = v ?? _category) : null,
            validator: (v) => (v == null || v.isEmpty) ? 'Escolha uma categoria.' : vm.fieldError('category'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _description,
            maxLength: 300,
            maxLines: 3,
            enabled: enabled,
            decoration: const InputDecoration(labelText: 'Descrição', alignLabelWithHint: true),
            validator: (_) => vm.fieldError('description'),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _price,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Preço', prefixText: 'R\$ ', hintText: '120,00'),
                  onChanged: (_) => vm.clearFieldError('price'),
                  validator: (v) {
                    final p = Fmt.parseMoney(v ?? '');
                    if (p == null || p <= 0 || p > 100000) return 'Informe um preço entre R\$ 0,01 e R\$ 100.000.';
                    return vm.fieldError('price');
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _duration,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Duração'),
                  items: [for (final d in durations) DropdownMenuItem(value: d, child: Text(Fmt.duration(d)))],
                  onChanged: enabled ? (v) => setState(() => _duration = v ?? _duration) : null,
                  validator: (_) => vm.fieldError('duration_min'),
                ),
              ),
            ],
          ),
          if (!vm.isNew)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Serviço ativo'),
              subtitle: const Text('Inativos não aparecem na busca'),
              value: _active,
              onChanged: enabled ? (v) => setState(() => _active = v) : null,
            ),
          const SizedBox(height: AppSpacing.sm),
          FormActions(submitLabel: 'Salvar', loading: vm.loading, onSubmit: _submit),
        ],
      ),
    );
  }
}

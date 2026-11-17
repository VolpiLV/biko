import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/order_model.dart';
import '../../../data/remote/catalog_service.dart';
import '../../../data/remote/order_service.dart';
import '../../../shared/widgets/app_ui.dart';
import '../viewmodels/booking_view_model.dart';

/// Abre o agendamento. Retorna o pedido criado (ou null se o usuário desistiu).
Future<OrderModel?> showBookingSheet(BuildContext context, ServiceModel service) {
  final catalog = context.read<CatalogService>();
  final orders = context.read<OrderService>();
  return showAppSheet<OrderModel>(
    context,
    (_) => ChangeNotifierProvider(
      create: (_) => BookingViewModel(service: service, catalog: catalog, orders: orders),
      child: const _BookingForm(),
    ),
  );
}

class _BookingForm extends StatefulWidget {
  const _BookingForm();

  @override
  State<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<_BookingForm> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _triedSubmit = false;

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final vm = context.read<BookingViewModel>();
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.date ?? vm.firstDay,
      firstDate: vm.firstDay,
      lastDate: vm.lastDay,
      helpText: 'Data do serviço',
    );
    if (picked != null) await vm.selectDate(picked);
  }

  Future<void> _submit() async {
    final vm = context.read<BookingViewModel>();
    setState(() => _triedSubmit = true);
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk || vm.date == null || vm.time == null) return;
    final order = await vm.book(address: _address.text, notes: _notes.text);
    if (!mounted) return;
    if (order != null) {
      Navigator.of(context).pop(order);
    } else {
      _formKey.currentState?.validate(); // mostra erros de campo vindos do servidor
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookingViewModel>();
    final theme = Theme.of(context);
    final s = vm.service;
    final dateError = vm.fieldError('date') ?? (_triedSubmit && vm.date == null ? 'Escolha a data.' : null);
    final timeError = vm.fieldError('time') ?? (_triedSubmit && vm.date != null && vm.time == null ? 'Escolha o horário.' : null);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Agendar serviço'),
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ListTile(
              leading: Icon(CategoryModel.iconFor(s.category)),
              title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${s.providerName} · ${Fmt.brl(s.price)} · ${Fmt.duration(s.durationMin)}'),
            ),
          ),
          FormError(vm.errorMessage),
          // Data
          InkWell(
            onTap: vm.loading ? null : _pickDate,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Data',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                errorText: dateError,
              ),
              child: Text(vm.date == null ? 'Escolher data' : Fmt.dateBR(Fmt.ymd(vm.date!))),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Horário
          if (vm.date == null)
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Horário',
                prefixIcon: const Icon(Icons.schedule_outlined),
                enabled: false,
                errorText: timeError,
              ),
              child: const Text('Escolha a data primeiro'),
            )
          else if (vm.loadingSlots)
            const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LinearProgressIndicator())
          else if (vm.slotsError case final err?)
            Text(err, style: TextStyle(color: theme.colorScheme.error))
          else ...[
            Text(
              vm.hasFreeSlot ? 'Horário' : 'Sem horários livres neste dia. Escolha outra data.',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final slot in vm.slots)
                  if (slot.available)
                    ChoiceChip(
                      label: Text(slot.time),
                      selected: vm.time == slot.time,
                      onSelected: vm.loading ? null : (sel) => vm.selectTime(sel ? slot.time : null),
                    )
                  else if (slot.busy)
                    Tooltip(
                      message: 'Ocupado',
                      child: ChoiceChip(label: Text(slot.time), selected: false, onSelected: null),
                    ),
              ],
            ),
            if (timeError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(timeError, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _address,
            maxLength: 200,
            enabled: !vm.loading,
            decoration: const InputDecoration(
              labelText: 'Endereço do serviço',
              hintText: 'Rua, número, bairro',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            onChanged: (_) => vm.clearFieldError('address'),
            validator: (v) {
              if ((v ?? '').trim().length < 5) return 'Informe o endereço do serviço.';
              return vm.fieldError('address');
            },
          ),
          TextFormField(
            controller: _notes,
            maxLength: 500,
            maxLines: 3,
            enabled: !vm.loading,
            decoration: const InputDecoration(
              labelText: 'Observações (opcional)',
              hintText: 'Conte o que precisa ser feito',
              alignLabelWithHint: true,
            ),
            validator: (_) => vm.fieldError('notes'),
          ),
          FormActions(cancelLabel: 'Voltar', submitLabel: 'Enviar pedido', loading: vm.loading, onSubmit: _submit),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/remote/catalog_service.dart';
import '../../../data/remote/order_service.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../home/app_navigator.dart';
import '../../search/viewmodels/booking_view_model.dart';
import 'payment_screen.dart';

/// "Escolha Data e Horário" (tela "Usua 4"): faixa de dias, horários livres e endereço.
class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key, required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) {
          final vm = BookingViewModel(service: service, catalog: context.read<CatalogService>(), orders: context.read<OrderService>());
          // Hoje já não cabe o serviço (atendimento até 20:00)? Começa em amanhã.
          final now = DateTime.now();
          final lastStart = now.add(BookingViewModel.minLead).add(Duration(minutes: service.durationMin));
          final fitsToday = lastStart.hour * 60 + lastStart.minute <= BookingViewModel.closeMinutes && lastStart.day == now.day;
          vm.selectDate(fitsToday ? vm.firstDay : vm.firstDay.add(const Duration(days: 1)));
          return vm;
        },
        child: const _BookingView(),
      );
}

class _BookingView extends StatefulWidget {
  const _BookingView();

  @override
  State<_BookingView> createState() => _BookingViewState();
}

class _BookingViewState extends State<_BookingView> {
  final _address = TextEditingController();
  final _notes = TextEditingController();
  String? _addressError;
  String? _timeError;

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vm = context.read<BookingViewModel>();
    setState(() {
      _timeError = vm.time == null ? 'Escolha um horário.' : null;
      _addressError = _address.text.trim().length < 5 ? 'Informe o endereço do serviço.' : null;
    });
    if (_timeError != null || _addressError != null) return;
    final order = await vm.book(address: _address.text, notes: _notes.text);
    if (!mounted || order == null) return;
    await replaceScreen<void>(context, PaymentScreen(orderId: order.id));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookingViewModel>();
    final c = context.bikoColors;
    final sv = vm.service;
    final day = vm.date ?? vm.firstDay;
    final days = [for (var i = 0; i < 14; i++) vm.firstDay.add(Duration(days: i))];

    return Scaffold(
      appBar: bikoAppBar(context, 'Escolha Data e Horário'),
      body: BikoPage(
        children: [
          const SizedBox(height: 10),
          BikoCard(
            child: Row(
              children: [
                BikoAvatar(name: sv.providerName, photoUrl: sv.providerPhotoUrl, size: 60, square: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sv.providerName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.ink)),
                      Text(sv.title, style: TextStyle(color: c.blue, fontSize: 13.5)),
                      Text('${Fmt.brl(sv.price)} · ${Fmt.duration(sv.durationMin)}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                BikoChip(label: 'Chat', soft: true, icon: Icons.chat_bubble_outline, onTap: () => openChat(context, sv.providerId)),
              ],
            ),
          ),
          BikoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Dia do Atendimento', style: TextStyle(fontWeight: FontWeight.w700, color: c.ink))),
                    Text('${Fmt.months[day.month - 1]} ${day.year}', style: TextStyle(color: c.blue, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 14),
                DayStrip(days: days, selected: day, onSelect: vm.selectDate),
              ],
            ),
          ),
          BikoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Horários Disponíveis', style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
                const SizedBox(height: 14),
                if (vm.loadingSlots)
                  Text('Carregando…', style: TextStyle(color: c.muted, fontSize: 12.5))
                else if (vm.slotsError case final msg?)
                  Text(msg, style: TextStyle(color: c.danger, fontSize: 12.5))
                else ...[
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.3,
                    children: [
                      for (final s in vm.slots)
                        _SlotButton(
                          label: s.time,
                          selected: vm.time == s.time,
                          enabled: s.available,
                          onTap: () {
                            setState(() => _timeError = null);
                            vm.selectTime(s.time);
                          },
                        ),
                    ],
                  ),
                  if (!vm.hasFreeSlot)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Sem horários livres neste dia. Escolha outro.', style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ),
                ],
                if (_timeError ?? vm.fieldError('time') ?? vm.fieldError('date') case final e?)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(e, style: TextStyle(color: c.danger, fontSize: 12))),
              ],
            ),
          ),
          BikoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Onde será o serviço?', style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) {
                    if (_addressError != null) setState(() => _addressError = null);
                  },
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Rua, número, bairro',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    errorText: _addressError ?? vm.fieldError('address'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notes,
                  maxLength: 500,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Conte o que precisa ser feito (opcional)',
                    errorText: vm.fieldError('notes'),
                  ),
                ),
                if (vm.errorMessage case final msg?) ...[const SizedBox(height: 12), ErrorBanner(message: msg)],
                const SizedBox(height: 16),
                BikoButton(label: 'Avançar para Pagamento', trailingIcon: Icons.arrow_forward, loading: vm.loading, onPressed: _submit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({required this.label, required this.selected, required this.enabled, required this.onTap});

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: enabled ? label : '$label indisponível',
      excludeSemantics: true,
      child: Material(
        color: !enabled ? c.neutralSoft : selected ? c.blueSoft : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? c.blue : c.line, width: selected ? 2 : 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: !enabled ? c.muted2 : selected ? c.blue : c.ink,
                decoration: enabled ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

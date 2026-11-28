import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order_model.dart';
import '../../../data/remote/order_service.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../home/app_navigator.dart';
import '../../home/viewmodels/home_navigation.dart';
import '../../orders/order_actions.dart';

/// "Pedido Confirmado!" (tela "Usua 6").
class ConfirmedScreen extends StatefulWidget {
  const ConfirmedScreen({super.key, required this.orderId, required this.paid});

  final int orderId;

  /// false = escolheu "Pagar depois".
  final bool paid;

  @override
  State<ConfirmedScreen> createState() => _ConfirmedScreenState();
}

class _ConfirmedScreenState extends State<ConfirmedScreen> {
  OrderModel? _order;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await context.read<OrderService>().detail(widget.orderId);
      if (mounted) setState(() => _order = o);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final o = _order;
    return Scaffold(
      backgroundColor: c.card,
      body: SafeArea(
        child: o == null
            ? (_error == null ? const LoadingView() : ErrorView(message: _error!, onRetry: _load))
            : BikoPage(
                children: [
                  const SizedBox(height: 50),
                  Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(color: c.greenSoft, shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded, color: c.green, size: 44),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.paid ? 'Pedido Confirmado!' : 'Pedido Enviado!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.ink),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(46, 8, 46, 22),
                    child: Text(
                      widget.paid
                          ? 'Pagamento aprovado. O serviço foi agendado e o profissional notificado.'
                          : 'O profissional foi notificado. Você pode pagar depois pela Agenda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted, height: 1.45),
                    ),
                  ),
                  BikoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            BikoAvatar(name: o.provider.name, photoUrl: o.provider.photoUrl, size: 60, square: true),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o.provider.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.ink)),
                                  const SizedBox(height: 4),
                                  OrderStatusTag(o, clientView: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const ThinDivider(),
                        IconLine(Icons.schedule, Text.rich(TextSpan(children: [
                          TextSpan(text: '${Fmt.dayLabel(o.date)} às '),
                          TextSpan(text: o.time, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ]))),
                        IconLine(Icons.location_on_outlined, Text(o.address)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: BikoButton(
                      label: 'Abrir Conversa com ${o.provider.name.split(' ').first}',
                      icon: Icons.chat_bubble_outline,
                      onPressed: () => openChat(context, o.provider.id),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: BikoButton(
                      label: 'Voltar para a Home',
                      style: BikoButtonStyle.light,
                      onPressed: () => goToTab(context, AppTab.home),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

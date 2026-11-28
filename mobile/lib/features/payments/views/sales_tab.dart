import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/payment_models.dart';
import '../../../data/models/user_role.dart';
import '../../../data/remote/payment_service.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../viewmodels/sales_view_model.dart';
import 'receipt_sheet.dart';

/// "Meus Pagamentos" do cliente (aberto pela Agenda ou pela Conta).
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.read<SessionViewModel>().user?.role ?? UserRole.cliente;
    return ChangeNotifierProvider(
      create: (_) => SalesViewModel(context.read<PaymentService>()),
      child: Scaffold(
        appBar: bikoAppBar(context, role == UserRole.cliente ? 'Meus Pagamentos' : 'Vendas'),
        body: SalesTab(role: role, withTitle: false),
      ),
    );
  }
}

/// Aba "Vendas" (admin) ou lista de pagamentos (cliente). Pagamento SIMULADO.
class SalesTab extends StatefulWidget {
  const SalesTab({super.key, required this.role, this.withTitle = true});

  final UserRole role;
  final bool withTitle;

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SalesViewModel>().refresh();
    });
  }

  Future<void> _loadMore() async {
    final vm = context.read<SalesViewModel>();
    await vm.loadMore();
    if (!mounted) return;
    if (vm.takeLoadMoreError() case final msg?) showAppSnackBar(context, msg, error: true);
  }

  List<(String, String)> _stats(SalesSummary s) => widget.role == UserRole.cliente
      ? [('${s.sales}', 'Pagamentos'), (Fmt.brl(s.gross), 'Total pago'), ('${s.refunds}', 'Estornos')]
      : [(Fmt.brl(s.gross), 'Vendido'), (Fmt.brl(s.fee), 'Taxas Biko'), (Fmt.brl(s.net), 'Repassado')];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SalesViewModel>();
    final role = widget.role;
    final c = context.bikoColors;
    return BikoPage(
      onRefresh: vm.refresh,
      children: [
        if (widget.withTitle) const PageTitle('Vendas') else const SizedBox(height: 8),
        const DemoBanner('Pagamentos simulados (TCC): nenhum valor é cobrado de verdade.'),
        if (vm.loading && !vm.loaded)
          const SizedBox(height: 240, child: LoadingView())
        else if (vm.errorMessage case final msg? when vm.items.isEmpty)
          SizedBox(height: 280, child: ErrorView(message: msg, onRetry: vm.refresh))
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final (i, (value, label)) in _stats(vm.summary).indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                      decoration: BoxDecoration(
                        color: c.card,
                        border: Border.all(color: c.line),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          FittedBox(child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.ink))),
                          Text(label, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Text(
              '${vm.total} transação(ões) · ${vm.summary.pix} Pix · ${vm.summary.card} cartão',
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
          ),
          if (vm.items.isEmpty)
            EmptyText(role == UserRole.cliente ? 'Você ainda não pagou nenhum pedido.' : 'Nenhuma venda ainda.')
          else
            for (final ch in vm.items)
              _ChargeRow(charge: ch, role: role, onTap: () => showReceiptSheet(context, ch, seller: role != UserRole.cliente)),
          LoadMoreButton(visible: vm.hasMore, loading: vm.loadingMore, onPressed: _loadMore),
        ],
      ],
    );
  }
}

class _ChargeRow extends StatelessWidget {
  const _ChargeRow({required this.charge, required this.role, required this.onTap});

  final Charge charge;
  final UserRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final ch = charge;
    final approved = ch.status == ChargeStatus.aprovado;
    final who = role == UserRole.cliente ? (ch.receiver.name ?? '') : '${ch.payer.name ?? ''} → ${ch.receiver.name ?? ''}';
    final tone = switch (ch.status) {
      ChargeStatus.aprovado => TagTone.green,
      ChargeStatus.aguardando => TagTone.orange,
      ChargeStatus.estornado => TagTone.purple,
      ChargeStatus.recusado || ChargeStatus.expirado => TagTone.red,
      ChargeStatus.outro => TagTone.gray,
    };
    return BikoCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: approved ? c.greenSoft : c.neutralSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(ch.method == PaymentMethod.pix ? Icons.pix : Icons.credit_card, color: approved ? c.green : c.muted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ch.description, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: c.ink)),
                Text('$who · ${ch.code}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Tag(ch.status.label, tone: tone),
              const SizedBox(height: 4),
              Text(Fmt.brl(ch.amount), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c.ink)),
            ],
          ),
        ],
      ),
    );
  }
}

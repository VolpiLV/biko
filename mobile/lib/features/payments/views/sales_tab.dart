import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/payment_models.dart';
import '../../../data/models/user_role.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../viewmodels/sales_view_model.dart';
import '../widgets/payment_widgets.dart';
import 'receipt_sheet.dart';

/// Aba "Pagamentos" (cliente) ou "Vendas" (prestador e admin). Pagamento SIMULADO.
class SalesTab extends StatefulWidget {
  const SalesTab({super.key, required this.role});

  final UserRole role;

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

  List<StatTile> _tiles(SalesSummary s) => switch (widget.role) {
        UserRole.cliente => [
            StatTile(value: '${s.sales}', label: 'Pagamentos'),
            StatTile(value: Fmt.brl(s.gross), label: 'Total pago'),
            StatTile(value: '${s.refunds}', label: 'Estornos'),
          ],
        UserRole.prestador => [
            StatTile(value: Fmt.brl(s.gross), label: 'Total vendido'),
            StatTile(value: Fmt.brl(s.fee), label: 'Taxa Biko (10%)'),
            StatTile(value: Fmt.brl(s.net), label: 'Você recebe'),
          ],
        UserRole.admin => [
            StatTile(value: Fmt.brl(s.gross), label: 'Vendido na plataforma'),
            StatTile(value: Fmt.brl(s.fee), label: 'Taxa Biko (10%)'),
            StatTile(value: Fmt.brl(s.net), label: 'Repassado'),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SalesViewModel>();
    final role = widget.role;
    return TabPage(
      onRefresh: vm.refresh,
      children: [
        const DemoNote(),
        if (vm.loading && !vm.loaded)
          const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView())
        else if (vm.errorMessage case final msg? when vm.items.isEmpty)
          Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: ErrorView(message: msg, onRetry: vm.refresh))
        else ...[
          if (vm.loading) const LinearProgressIndicator(),
          StatRow(tiles: _tiles(vm.summary)),
          CountLabel('${vm.total} transação(ões) · ${vm.summary.pix} Pix · ${vm.summary.card} cartão'),
          if (vm.items.isEmpty)
            EmptyView(
              icon: Icons.receipt_long_outlined,
              message: role == UserRole.cliente
                  ? 'Você ainda não pagou nenhum pedido.\nQuando o prestador confirmar um pedido, o botão Pagar aparece nele.'
                  : 'Nenhuma venda ainda.',
            )
          else
            for (final c in vm.items)
              _ChargeCard(
                charge: c,
                role: role,
                onTap: () => showReceiptSheet(context, c, seller: role != UserRole.cliente),
              ),
          LoadMoreButton(visible: vm.hasMore, loading: vm.loadingMore, onPressed: _loadMore),
        ],
      ],
    );
  }
}

class _ChargeCard extends StatelessWidget {
  const _ChargeCard({required this.charge, required this.role, required this.onTap});

  final Charge charge;
  final UserRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = charge;
    final who = switch (role) {
      UserRole.cliente => c.receiver.name ?? '',
      UserRole.prestador => c.payer.name ?? '',
      UserRole.admin => '${c.payer.name ?? ''} → ${c.receiver.name ?? ''}',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Icon(c.method == PaymentMethod.pix ? Icons.pix : Icons.credit_card),
              ),
              const SizedBox(width: AppSpacing.md - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.description, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (who.isNotEmpty) Text(who, style: theme.textTheme.bodySmall),
                    Text('${c.methodLabel} · ${c.code}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ChargePill(status: c.status),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    Fmt.brl(role == UserRole.prestador ? c.net : c.amount),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

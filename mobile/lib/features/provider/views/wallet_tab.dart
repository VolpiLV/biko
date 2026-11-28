import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/provider_models.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../viewmodels/provider_view_models.dart';

/// "Ganhos e Carteira" (tela "Prest 7") — SIMULADO: saldo, pendente, este mês e saque via Pix.
class WalletTab extends StatefulWidget {
  const WalletTab({super.key});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<WalletViewModel>().load());
  }

  void _help() => showBikoSheet<void>(
        context,
        (sheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('Como funciona'),
            Text(
              'O cliente paga ao agendar. O valor fica pendente até você concluir o serviço; aí ele vai para o '
              'saldo disponível. O Biko fica com 10% do serviço (a Taxa de Proteção é paga pelo cliente).\n\n'
              'Se o pedido for recusado ou cancelado, o cliente recebe o estorno.',
              style: TextStyle(color: sheet.bikoColors.muted, height: 1.55),
            ),
            const SizedBox(height: 18),
            BikoButton(label: 'Entendi', style: BikoButtonStyle.light, onPressed: () => Navigator.pop(sheet)),
          ],
        ),
      );

  Future<void> _withdraw(Wallet w) async {
    final message = await showBikoSheet<String>(
      context,
      (_) => ChangeNotifierProvider.value(value: context.read<WalletViewModel>(), child: _WithdrawSheet(wallet: w)),
    );
    if (message != null && mounted) showAppSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WalletViewModel>();
    final c = context.bikoColors;
    final w = vm.wallet;
    return BikoPage(
      onRefresh: vm.load,
      children: [
        PageTitle(
          'Ganhos e Carteira',
          trailing: IconButton(tooltip: 'Ajuda', onPressed: _help, icon: Icon(Icons.help_outline, color: c.muted)),
        ),
        if (w == null)
          vm.loading
              ? const SizedBox(height: 300, child: LoadingView())
              : SizedBox(height: 300, child: ErrorView(message: vm.error ?? 'Não foi possível carregar.', onRetry: vm.load))
        else ...[
          Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0A84FF), Color(0xFF0050CC)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo disponível para saque', style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13.5)),
                const SizedBox(height: 8),
                FittedBox(
                  child: Text(Fmt.brl(w.available), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 18),
                BikoButton(
                  label: 'Transferir via Pix',
                  icon: Icons.pix,
                  style: BikoButtonStyle.orange,
                  onPressed: w.available > 0 ? () => _withdraw(w) : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _Stat(label: 'Pendente', value: Fmt.brl(w.pending))),
                const SizedBox(width: 12),
                Expanded(child: _Stat(label: 'Este Mês', value: Fmt.brl(w.thisMonth), green: true)),
              ],
            ),
          ),
          const SectionHeader('Histórico Recente'),
          if (w.history.isEmpty)
            const EmptyText('Quando os clientes pagarem, os valores aparecem aqui.')
          else
            for (final h in w.history) _EntryRow(entry: h),
          const DemoBanner('Carteira simulada (TCC): nenhum dinheiro é transferido de verdade.'),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.green = false});

  final String label;
  final String value;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return BikoCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.muted, fontSize: 13)),
          const SizedBox(height: 6),
          FittedBox(child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: green ? c.green : c.ink))),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final WalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final h = entry;
    final out = h.isWithdrawal;
    return BikoCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: out ? c.neutralSoft : c.greenSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(out ? Icons.arrow_upward : Icons.arrow_downward, color: out ? c.muted : c.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: c.ink)),
                Text(
                  '${Fmt.dayOf(h.when)} às ${Fmt.time(h.when)}${!out && !h.released ? ' · libera ao concluir' : ''}',
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Text(
            '${out ? '- ' : '+ '}${Fmt.brl(h.amount)}',
            style: TextStyle(fontWeight: FontWeight.w700, color: out ? c.ink : c.green),
          ),
        ],
      ),
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({required this.wallet});

  final Wallet wallet;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  late final _value = TextEditingController(text: widget.wallet.available.toStringAsFixed(2).replaceAll('.', ','));
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final (ok, error) = await context.read<WalletViewModel>().withdraw(_value.text);
    if (!mounted) return;
    if (ok != null) {
      Navigator.pop(context, ok);
    } else {
      setState(() {
        _sending = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle('Transferir via Pix'),
        Text('Chave Pix: ${widget.wallet.pixKey}', style: TextStyle(color: c.muted, fontSize: 12.5)),
        FieldLabel('Valor (disponível ${Fmt.brl(widget.wallet.available)})'),
        TextField(
          controller: _value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
          decoration: InputDecoration(errorText: _error, prefixText: 'R\$ '),
        ),
        const SizedBox(height: 18),
        ButtonPair(
          left: BikoButton(label: 'Cancelar', style: BikoButtonStyle.light, onPressed: () => Navigator.pop(context)),
          right: BikoButton(label: 'Transferir', style: BikoButtonStyle.orange, loading: _sending, onPressed: _go),
        ),
      ],
    );
  }
}

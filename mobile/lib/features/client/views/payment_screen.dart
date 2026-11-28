import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/payment_models.dart';
import '../../../data/remote/order_service.dart';
import '../../../data/remote/payment_service.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/state_views.dart';
import '../../home/app_navigator.dart';
import '../../payments/viewmodels/payment_view_model.dart';
import '../../payments/widgets/payment_widgets.dart';
import 'confirmed_screen.dart';

/// "Pagamento Seguro" (tela "Usua 5") — SIMULADO: resumo + Taxa de Proteção, Pix ou cartão.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  OrderModel? _order;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final o = await context.read<OrderService>().detail(widget.orderId);
      if (mounted) setState(() => _order = o);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    if (o == null) {
      return Scaffold(
        appBar: bikoAppBar(context, 'Pagamento Seguro'),
        body: _error == null ? const LoadingView() : ErrorView(message: _error!, onRetry: _load),
      );
    }
    if (!o.canPay) {
      return Scaffold(
        appBar: bikoAppBar(context, 'Pagamento Seguro'),
        body: BikoPage(
          children: [
            const EmptyText('Este pedido já foi pago ou não pode mais ser pago.'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: BikoButton(label: 'Ver pedido', onPressed: () => openOrder(context, o.id)),
            ),
          ],
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => PaymentViewModel(context.read<PaymentService>(), o),
      child: const _PaymentView(),
    );
  }
}

class _PaymentView extends StatelessWidget {
  const _PaymentView();

  void _done(BuildContext context, {required bool paid}) =>
      replaceScreen<void>(context, ConfirmedScreen(orderId: context.read<PaymentViewModel>().order.id, paid: paid));

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PaymentViewModel>();
    final o = vm.order;
    final c = context.bikoColors;
    final m = vm.method;
    return Scaffold(
      appBar: bikoAppBar(context, 'Pagamento Seguro'),
      body: BikoPage(
        children: [
          const SizedBox(height: 10),
          BikoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CardTitle('Resumo do Pedido'),
                KeyValue('${o.serviceTitle} (${o.provider.name})', Fmt.brl(o.price)),
                KeyValue('Taxa de Proteção Biko', Fmt.brl(o.protectionFee)),
                KeyValue('Total', Fmt.brl(o.total), total: true),
              ],
            ),
          ),
          const SectionHeader('Escolha como pagar'),
          _MethodCard(
            selected: m == PaymentMethod.pix,
            icon: Icons.pix,
            iconBg: c.greenSoft,
            iconFg: c.green,
            title: 'Pix (Instantâneo)',
            onTap: vm.loading ? null : () => vm.toggleMethod(PaymentMethod.pix),
            body: const _PixBody(),
          ),
          _MethodCard(
            selected: m == PaymentMethod.cartao,
            icon: Icons.credit_card,
            iconBg: c.blueSoft,
            iconFg: c.blue,
            title: 'Cartão de Crédito',
            onTap: vm.loading ? null : () => vm.toggleMethod(PaymentMethod.cartao),
            body: _CardBody(onApproved: () => _done(context, paid: true)),
          ),
          const DemoBanner('Ambiente de demonstração (TCC): nenhum valor é cobrado. Não use dados reais.'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (m != PaymentMethod.cartao)
                  BikoButton(
                    label: m == null ? 'Escolha como pagar' : 'Confirmar Pagamento ${Fmt.brl(o.total)}',
                    icon: Icons.lock_outline,
                    style: BikoButtonStyle.green,
                    loading: vm.loading && vm.pix != null,
                    onPressed: m == PaymentMethod.pix && vm.pix != null
                        ? () async {
                            final ok = await vm.confirmPix();
                            if (!context.mounted) return;
                            if (ok) {
                              _done(context, paid: true);
                            } else if (vm.errorMessage case final msg?) {
                              showAppSnackBar(context, msg, error: true);
                            }
                          }
                        : null,
                  ),
                const SizedBox(height: 6),
                LinkText('Pagar depois', color: c.muted, onTap: () => _done(context, paid: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.selected,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.onTap,
    required this.body,
  });

  final bool selected;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final VoidCallback? onTap;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: c.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? c.blue : c.line, width: selected ? 2 : 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              selected: selected,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, color: iconFg, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: c.ink))),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? c.blue : c.muted2, width: 2),
                        ),
                        child: selected
                            ? Center(child: Container(width: 9, height: 9, decoration: BoxDecoration(color: c.blue, shape: BoxShape.circle)))
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (selected)
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
                child: Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 18), child: body),
              ),
          ],
        ),
      ),
    );
  }
}

class _PixBody extends StatelessWidget {
  const _PixBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PaymentViewModel>();
    final c = context.bikoColors;
    final pix = vm.pix;
    if (pix == null) {
      if (vm.errorMessage case final msg?) return ErrorBanner(message: msg);
      return const SizedBox(height: 150, child: LoadingView(message: 'Gerando…'));
    }
    final code = pix.pixCode ?? '';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
          child: FakeQrCode(data: code, size: 122, dark: true),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: c.neutralSoft, borderRadius: BorderRadius.circular(10)),
          child: SingleChildScrollView(
            child: SelectableText(code, style: TextStyle(fontSize: 11, color: c.muted, fontFamily: 'monospace')),
          ),
        ),
        const SizedBox(height: 10),
        _PixTimer(expiresAt: pix.expiresAt),
        const SizedBox(height: 8),
        BikoButton(
          label: 'Copiar Código Pix',
          icon: Icons.copy,
          style: BikoButtonStyle.light,
          small: true,
          expand: false,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) showAppSnackBar(context, 'Código Pix copiado.');
          },
        ),
      ],
    );
  }
}

class _PixTimer extends StatefulWidget {
  const _PixTimer({required this.expiresAt});

  final DateTime? expiresAt;

  @override
  State<_PixTimer> createState() => _PixTimerState();
}

class _PixTimerState extends State<_PixTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.expiresAt;
    var left = exp == null ? Duration.zero : exp.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    return Text(
      'Expira em ${Fmt.two(left.inMinutes)}:${Fmt.two(left.inSeconds % 60)}',
      style: TextStyle(fontSize: 12.5, color: context.bikoColors.muted),
    );
  }
}

class _CardBody extends StatefulWidget {
  const _CardBody({required this.onApproved});

  final VoidCallback onApproved;

  @override
  State<_CardBody> createState() => _CardBodyState();
}

class _CardBodyState extends State<_CardBody> {
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  int _installments = 1;
  Map<String, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    for (final ctl in [_number, _name]) {
      ctl.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final ctl in [_number, _name, _expiry, _cvv]) {
      ctl.dispose();
    }
    super.dispose();
  }

  String get _digits => _number.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _submit() async {
    final digits = _digits;
    final errors = <String, String>{};
    if (digits.length < 13) errors['number'] = 'Número do cartão incompleto.';
    if (_name.text.trim().length < 3) errors['name'] = 'Informe o nome como está no cartão.';
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(_expiry.text);
    final month = m == null ? 0 : int.parse(m.group(1)!);
    if (month < 1 || month > 12) errors['expiry'] = 'Validade inválida.';
    if (!RegExp(r'^\d{3,4}$').hasMatch(_cvv.text)) errors['cvv'] = 'CVV inválido.';
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    // Só o final, a bandeira e as parcelas vão para o servidor. O número inteiro e o CVV ficam aqui.
    final ok = await context.read<PaymentViewModel>().payCard(
          last4: digits.substring(digits.length - 4),
          brand: cardBrandOf(digits),
          installments: _installments,
        );
    if (mounted && ok) widget.onApproved();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PaymentViewModel>();
    final total = vm.order.total;
    final c = context.bikoColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardPreview(digits: _digits, name: _name.text, brand: cardBrandOf(_digits)),
        TextField(
          controller: _number,
          keyboardType: TextInputType.number,
          inputFormatters: [CardNumberFormatter()],
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(hintText: 'Número do cartão', errorText: _errors['number']),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(hintText: 'Nome no cartão', errorText: _errors['name']),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _expiry,
                keyboardType: TextInputType.number,
                inputFormatters: [CardExpiryFormatter()],
                decoration: InputDecoration(hintText: 'MM/AA', errorText: _errors['expiry']),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _cvv,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(hintText: 'CVV', counterText: '', errorText: _errors['cvv']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _installments,
          isExpanded: true,
          items: [
            for (final n in [1, 2, 3]) DropdownMenuItem(value: n, child: Text('${n}x de ${Fmt.brl(total / n)} sem juros')),
          ],
          onChanged: vm.loading ? null : (v) => setState(() => _installments = v ?? 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Teste: 4242 4242 4242 4242 aprova; final 0002 é recusado. Só os 4 últimos dígitos saem do aparelho.',
            style: TextStyle(color: c.muted, fontSize: 12.5),
          ),
        ),
        if (vm.cardDeclined case final msg?)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: ErrorBanner(message: '❌ $msg. Tente outro cartão ou pague com Pix.'))
        else if (vm.errorMessage case final msg?)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: ErrorBanner(message: msg)),
        BikoButton(
          label: 'Confirmar Pagamento ${Fmt.brl(total)}',
          icon: Icons.lock_outline,
          style: BikoButtonStyle.green,
          loading: vm.loading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

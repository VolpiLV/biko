import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/payment_models.dart';
import '../../../data/remote/payment_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/state_views.dart';
import '../viewmodels/payment_view_model.dart';
import '../widgets/payment_widgets.dart';

/// Abre o pagamento do pedido (SIMULADO). Retorna a cobrança aprovada, ou null se a pessoa saiu.
Future<Charge?> showPaymentSheet(BuildContext context, OrderModel order) {
  final service = context.read<PaymentService>();
  return showAppSheet<Charge>(
    context,
    (_) => ChangeNotifierProvider(
      create: (_) => PaymentViewModel(service, order)..resume(),
      child: const _PaymentForm(),
    ),
  );
}

class _PaymentForm extends StatelessWidget {
  const _PaymentForm();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PaymentViewModel>();
    final order = vm.order;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: 'Pagamento',
          trailing: Text(Fmt.brl(order.price), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        InfoRow(label: 'Serviço', value: order.serviceTitle),
        InfoRow(label: 'Prestador', value: order.provider.name),
        InfoRow(label: 'Quando', value: '${Fmt.dateBR(order.date)} · ${order.time}'),
        const DemoNote(),
        if (vm.resuming)
          const SizedBox(height: 160, child: LoadingView())
        else if (vm.pix case final pix?)
          _PixView(charge: pix)
        else ...[
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<PaymentMethod>(
            segments: const [
              ButtonSegment(value: PaymentMethod.pix, icon: Icon(Icons.pix), label: Text('Pix')),
              ButtonSegment(value: PaymentMethod.cartao, icon: Icon(Icons.credit_card), label: Text('Cartão')),
            ],
            selected: {vm.method},
            onSelectionChanged: vm.loading ? null : (s) => vm.setMethod(s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          if (vm.method == PaymentMethod.pix) const _PixStart() else const _CardForm(),
        ],
      ],
    );
  }
}

class _PixStart extends StatelessWidget {
  const _PixStart();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PaymentViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Aprovação na hora. Vamos gerar um código Pix para este pedido.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        if (vm.errorMessage case final msg?)
          Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: ErrorBanner(message: msg)),
        AppButton(label: 'Gerar Pix de ${Fmt.brl(vm.order.price)}', loading: vm.loading, onPressed: vm.generatePix),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: 'Voltar', variant: AppButtonVariant.secondary, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _PixView extends StatefulWidget {
  const _PixView({required this.charge});

  final Charge charge;

  @override
  State<_PixView> createState() => _PixViewState();
}

class _PixViewState extends State<_PixView> {
  Timer? _timer;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _left = _remaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _left = _remaining());
      if (_left == Duration.zero) _timer?.cancel();
    });
  }

  Duration _remaining() {
    final exp = widget.charge.expiresAt;
    final left = exp == null ? Duration.zero : exp.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.charge.pixCode ?? ''));
    if (mounted) showAppSnackBar(context, 'Código Pix copiado.');
  }

  Future<void> _simulate() async {
    final vm = context.read<PaymentViewModel>();
    final ok = await vm.confirmPix();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(vm.approved);
    } else if (vm.errorMessage case final msg?) {
      showAppSnackBar(context, msg, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PaymentViewModel>();
    final theme = Theme.of(context);
    final code = widget.charge.pixCode ?? '';
    final mm = Fmt.two(_left.inMinutes), ss = Fmt.two(_left.inSeconds % 60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Center(child: FakeQrCode(data: code)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Escaneie o QR Code no app do seu banco ou use o Pix copia e cola',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
          child: SelectableText(
            code,
            maxLines: 3,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ),
        Center(
          child: OutlinedButton.icon(onPressed: _copy, icon: const Icon(Icons.copy, size: 18), label: const Text('Copiar código')),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text.rich(
          TextSpan(text: 'Expira em ', children: [TextSpan(text: '$mm:$ss', style: const TextStyle(fontWeight: FontWeight.w700))]),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Simular pagamento recebido (demo)', loading: vm.loading, onPressed: _simulate),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: 'Fechar', variant: AppButtonVariant.secondary, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _CardForm extends StatefulWidget {
  const _CardForm();

  @override
  State<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<_CardForm> {
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  int _installments = 1;
  Map<String, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    for (final c in [_number, _name]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_number, _name, _expiry, _cvv]) {
      c.dispose();
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

    final vm = context.read<PaymentViewModel>();
    // Só o final, a bandeira e as parcelas vão para o servidor. O número inteiro e o CVV ficam aqui.
    final ok = await vm.payCard(
      last4: digits.substring(digits.length - 4),
      brand: cardBrandOf(digits),
      installments: _installments,
    );
    if (!mounted) return;
    if (ok) Navigator.of(context).pop(vm.approved);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PaymentViewModel>();
    final price = vm.order.price;
    final theme = Theme.of(context);
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
          decoration: InputDecoration(labelText: 'Número do cartão', hintText: '4242 4242 4242 4242', errorText: _errors['number']),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: 'Nome no cartão', errorText: _errors['name']),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _expiry,
                keyboardType: TextInputType.number,
                inputFormatters: [CardExpiryFormatter()],
                decoration: InputDecoration(labelText: 'Validade', hintText: 'MM/AA', errorText: _errors['expiry']),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _cvv,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: 'CVV', counterText: '', errorText: _errors['cvv']),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<int>(
          initialValue: _installments,
          decoration: const InputDecoration(labelText: 'Parcelas'),
          items: [
            for (final n in [1, 2, 3])
              DropdownMenuItem(value: n, child: Text('${n}x de ${Fmt.brl(price / n)} sem juros')),
          ],
          onChanged: vm.loading ? null : (v) => setState(() => _installments = v ?? 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(
            'Teste: 4242 4242 4242 4242 é aprovado; um cartão terminado em 0002 é recusado. '
            'Só os 4 últimos dígitos saem do seu aparelho.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (vm.cardDeclined case final msg?)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ErrorBanner(message: '$msg. Tente outro cartão ou pague com Pix.'),
          )
        else if (vm.errorMessage case final msg?)
          Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: ErrorBanner(message: msg)),
        AppButton(label: 'Pagar ${Fmt.brl(price)}', loading: vm.loading, onPressed: _submit),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: 'Voltar', variant: AppButtonVariant.secondary, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

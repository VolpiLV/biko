import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/payment_models.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_ui.dart';
import '../widgets/payment_widgets.dart';

/// Comprovante de pagamento. [seller] = prestador/admin (vê a taxa e o líquido).
Future<void> showReceiptSheet(BuildContext context, Charge charge, {bool seller = false, bool justPaid = false}) =>
    showAppSheet<void>(context, (_) => _Receipt(charge: charge, seller: seller, justPaid: justPaid));

class _Receipt extends StatelessWidget {
  const _Receipt({required this.charge, required this.seller, required this.justPaid});

  final Charge charge;
  final bool seller;
  final bool justPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.bikoColors;
    final c = charge;
    final (icon, color) = switch (c.status) {
      ChargeStatus.aprovado => (Icons.check, brand.success),
      ChargeStatus.estornado => (Icons.undo, theme.colorScheme.secondary),
      ChargeStatus.aguardando => (Icons.hourglass_top, brand.highlight),
      _ => (Icons.close, theme.colorScheme.error),
    };
    final title = c.status == ChargeStatus.aprovado
        ? (justPaid ? 'Pagamento aprovado!' : 'Pagamento aprovado')
        : c.status.label;
    final payment = c.method == PaymentMethod.pix
        ? 'Pix'
        : '${c.cardBrand ?? 'Cartão'} •••• ${c.cardLast4 ?? '----'} · '
            '${c.installments > 1 ? '${c.installments}x de ${Fmt.brl(c.amount / c.installments)}' : 'à vista'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CircleAvatar(
            radius: 30,
            backgroundColor: color,
            child: Icon(icon, size: 32, color: Colors.white),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        Text(
          Fmt.brl(c.amount),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const DemoNote(),
        InfoRow(label: 'Serviço', value: c.description),
        InfoRow(label: 'Pago por', value: c.payer.name ?? '—'),
        InfoRow(label: 'Recebido por', value: c.receiver.name ?? '—'),
        InfoRow(label: 'Forma', value: payment),
        InfoRow(label: c.paidAt != null ? 'Pago em' : 'Criado em', value: Fmt.dateTime(c.paidAt ?? c.createdAt)),
        InfoRow(label: 'Transação', value: c.code),
        if (c.authorization case final auth?) InfoRow(label: 'Autorização', value: auth),
        if (seller) ...[
          InfoRow(label: 'Taxa Biko (10%)', value: '− ${Fmt.brl(c.fee)}'),
          InfoRow(label: 'Valor líquido', value: Fmt.brl(c.net)),
        ],
        if (c.reason case final r? when r.isNotEmpty) InfoRow(label: 'Observação', value: r),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Fechar',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

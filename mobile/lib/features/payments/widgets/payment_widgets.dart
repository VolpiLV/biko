import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/payment_models.dart';
import '../../../shared/widgets/app_ui.dart';

/// Aviso fixo das telas de pagamento: é tudo de mentira.
class DemoNote extends StatelessWidget {
  const DemoNote({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md - 4, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(AppRadius.sm + 2)),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Ambiente de demonstração (TCC): nenhum valor é cobrado. Não use dados reais.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selo do pagamento do pedido ("Pago", "Aguardando Pix"...). Recusado não aparece.
class PaymentPill extends StatelessWidget {
  const PaymentPill({super.key, required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.bikoColors;
    final (bg, fg) = switch (status) {
      PaymentStatus.pago => (brand.success, brand.onSuccess),
      PaymentStatus.aguardando => (brand.highlight, brand.onHighlight),
      PaymentStatus.estornado || PaymentStatus.estornoPendente => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Pill(label: status == PaymentStatus.pago ? '✓ Pago' : status.label, background: bg, foreground: fg);
  }
}

/// Selo de uma cobrança na lista de vendas.
class ChargePill extends StatelessWidget {
  const ChargePill({super.key, required this.status});

  final ChargeStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.bikoColors;
    final (bg, fg) = switch (status) {
      ChargeStatus.aprovado => (brand.success, brand.onSuccess),
      ChargeStatus.aguardando => (brand.highlight, brand.onHighlight),
      ChargeStatus.estornado => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Pill(label: status.label, background: bg, foreground: fg);
  }
}

/// "QR Code" de enfeite: desenho gerado a partir do código Pix (não é um QR de verdade).
class FakeQrCode extends StatelessWidget {
  const FakeQrCode({super.key, required this.data, this.size = 190});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Semantics(
          label: 'QR Code Pix (demonstração)',
          child: CustomPaint(size: Size.square(size), painter: _QrPainter(data)),
        ),
      );
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.data);

  final String data;
  static const _n = 25;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _n;
    final paint = Paint()..color = const Color(0xFF14213D);
    // Gerador "aleatório" a partir do texto (Park–Miller). As contas ficam abaixo de 2^53,
    // então o desenho sai igual no celular e no Chrome.
    const m = 2147483647;
    var h = 7;
    for (final c in data.codeUnits) {
      h = (h * 31 + c) % m;
    }
    if (h == 0) h = 1;
    double rnd() {
      h = (h * 48271) % m;
      return h / m;
    }

    bool inFinder(int x, int y) =>
        [(0, 0), (_n - 7, 0), (0, _n - 7)].any((f) => x >= f.$1 && x < f.$1 + 7 && y >= f.$2 && y < f.$2 + 7);
    bool finderOn(int x, int y) {
      final dx = x - (x < 7 ? 0 : _n - 7), dy = y - (y < 7 ? 0 : _n - 7);
      return dx == 0 || dy == 0 || dx == 6 || dy == 6 || (dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4);
    }

    for (var y = 0; y < _n; y++) {
      for (var x = 0; x < _n; x++) {
        final on = inFinder(x, y) ? finderOn(x, y) : rnd() > 0.52;
        if (on) canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.data != data;
}

/// Cartão desenhado que se preenche enquanto a pessoa digita.
class CardPreview extends StatelessWidget {
  const CardPreview({super.key, required this.digits, required this.name, required this.brand});

  final String digits;
  final String name;
  final String brand;

  @override
  Widget build(BuildContext context) {
    final padded = digits.padRight(16, '•').substring(0, 16);
    final groups = [for (var i = 0; i < 16; i += 4) padded.substring(i, i + 4)].join('  ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      constraints: const BoxConstraints(minHeight: 130),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg - 4),
        gradient: const LinearGradient(
          colors: [AppColors.brandBlue, Color(0xFF0B3F8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(brand, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            child: Text(
              groups,
              style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 2, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            name.trim().isEmpty ? 'NOME NO CARTÃO' : name.toUpperCase(),
            style: const TextStyle(color: Colors.white70, letterSpacing: 1, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Número do cartão em blocos de 4: "4242 4242 4242 4242".
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 16) digits = digits.substring(0, 16);
    final text = digits.replaceAllMapped(RegExp(r'(\d{4})(?=\d)'), (m) => '${m[1]} ');
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Validade "MM/AA".
class CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    final text = digits.length > 2 ? '${digits.substring(0, 2)}/${digits.substring(2)}' : digits;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

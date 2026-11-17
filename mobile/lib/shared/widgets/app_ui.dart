import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/biko_colors.dart';
import '../../data/models/order_model.dart';
import 'app_button.dart';
import 'error_banner.dart';

/// Abre um formulário/detalhe como "folha" que sobe do rodapé, com largura máxima
/// (no Chrome em tela larga não estica de ponta a ponta) e rolagem com teclado.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: builder(sheetContext),
        ),
      ),
    );

/// Título da folha com o botão de fechar.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
            ?trailing,
          ],
        ),
      );
}

/// Botões "Cancelar" + ação principal no rodapé dos formulários.
class FormActions extends StatelessWidget {
  const FormActions({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.loading = false,
    this.cancelLabel = 'Cancelar',
  });

  final String submitLabel;
  final String cancelLabel;
  final VoidCallback onSubmit;
  final bool loading;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: cancelLabel,
                variant: AppButtonVariant.secondary,
                onPressed: loading ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: AppButton(label: submitLabel, loading: loading, onPressed: onSubmit)),
          ],
        ),
      );
}

/// Banner de erro geral do formulário (só aparece quando há mensagem).
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ErrorBanner(message: text),
    );
  }
}

/// Selo colorido do status do pedido.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.bikoColors;
    final (bg, fg) = switch (status) {
      OrderStatus.pendente => (brand.highlight, brand.onHighlight),
      OrderStatus.confirmado => (scheme.primaryContainer, scheme.onPrimaryContainer),
      OrderStatus.concluido => (brand.success, brand.onSuccess),
      OrderStatus.recusado || OrderStatus.cancelado => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Pill(label: status.label, background: bg, foreground: fg);
  }
}

/// Selo simples (status do pedido, ativo/inativo).
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.background, required this.foreground});

  /// Selo "Ativo"/"Inativo" com as cores do tema.
  factory Pill.active(BuildContext context, {required bool active, String? on, String? off}) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.bikoColors;
    return Pill(
      label: active ? (on ?? 'Ativo') : (off ?? 'Inativo'),
      background: active ? brand.success : scheme.surfaceContainerHighest,
      foreground: active ? brand.onSuccess : scheme.onSurfaceVariant,
    );
  }

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Text(label, style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

/// Número de destaque do painel (ex.: "3 / Pedidos novos").
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        child: Column(
          children: [
            FittedBox(
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(label, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Linha de 3 números do painel.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      );
}

/// Estado "lista vazia" com ícone, texto e ação opcional.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined, this.action});

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          if (action case final a?) ...[const SizedBox(height: AppSpacing.md), a],
        ],
      ),
    );
  }
}

/// Título de seção dentro das listas.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.md, AppSpacing.xs, AppSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

/// Contador "N item(ns)" acima das listas.
class CountLabel extends StatelessWidget {
  const CountLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}

/// Rodapé das listas paginadas: botão "Carregar mais".
class LoadMoreButton extends StatelessWidget {
  const LoadMoreButton({super.key, required this.visible, required this.loading, required this.onPressed});

  final bool visible;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: AppButton(
          label: 'Carregar mais',
          loading: loading,
          variant: AppButtonVariant.secondary,
          expand: false,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// Linha "rótulo: valor" usada no detalhe do pedido.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.extra});

  final String label;
  final String value;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (extra case final e?) Text(e, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Moldura das abas: largura máxima em telas largas e "puxar para atualizar".
class TabPage extends StatelessWidget {
  const TabPage({super.key, required this.children, this.onRefresh});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final child in children)
          Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: child),
          ),
      ],
    );
    final refresh = onRefresh;
    return refresh == null ? list : RefreshIndicator(onRefresh: refresh, child: list);
  }
}

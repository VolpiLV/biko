import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/catalog_models.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../home/viewmodels/home_navigation.dart';
import '../../orders/viewmodels/orders_view_model.dart';
import '../viewmodels/search_view_model.dart';
import 'booking_sheet.dart';

/// Aba "Buscar" do cliente.
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  late final SearchViewModel _vm = context.read<SearchViewModel>();
  late final TextEditingController _query = TextEditingController(text: _vm.filters.query);
  late final TextEditingController _maxPrice = TextEditingController(
    text: _vm.filters.maxPrice == null ? '' : _vm.filters.maxPrice!.toStringAsFixed(0),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _vm.loadCategories();
      _vm.refresh();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  void _clear() {
    _query.clear();
    _maxPrice.clear();
    _vm.clearFilters();
  }

  Future<void> _book(ServiceModel service) async {
    final orders = context.read<OrdersViewModel>();
    final nav = context.read<HomeNavigation>();
    final messenger = ScaffoldMessenger.of(context);
    final order = await showBookingSheet(context, service);
    if (order == null) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Pedido enviado! Aguarde a confirmação do prestador.')),
    );
    orders.setFilter(null, reload: false);
    nav.goTo(AppTab.orders);
  }

  Future<void> _loadMore() async {
    await _vm.loadMore();
    if (!mounted) return;
    if (_vm.takeLoadMoreError() case final msg?) showAppSnackBar(context, msg, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final f = vm.filters;
    final categoryNames = {for (final c in vm.categories) c.name, if (f.category.isNotEmpty) f.category};

    return TabPage(
      onRefresh: vm.refresh,
      children: [
        TextField(
          controller: _query,
          maxLength: 80,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'O que você procura? (ex.: vazamento, pintura)',
            prefixIcon: Icon(Icons.search),
            counterText: '',
          ),
          onChanged: vm.setQuery,
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 520;
            final category = DropdownButtonFormField<String>(
              key: ValueKey('cat-${f.category}-${categoryNames.length}'),
              initialValue: f.category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Todas as categorias')),
                for (final name in categoryNames) DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: (v) => vm.setCategory(v ?? ''),
            );
            final sort = DropdownButtonFormField<SearchSort>(
              key: ValueKey('sort-${f.sort}'),
              initialValue: f.sort,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ordenar por'),
              items: [for (final s in SearchSort.values) DropdownMenuItem(value: s, child: Text(s.label))],
              onChanged: (v) => vm.setSort(v ?? SearchSort.relevance),
            );
            final price = TextField(
              controller: _maxPrice,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Preço máximo (R\$)', prefixText: 'R\$ '),
              onChanged: (t) => vm.setMaxPrice(t.trim().isEmpty ? null : Fmt.parseMoney(t)),
            );
            if (wide) {
              return Row(
                children: [
                  Expanded(flex: 3, child: category),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(flex: 2, child: sort),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(flex: 2, child: price),
                ],
              );
            }
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: category),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: sort),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                price,
              ],
            );
          },
        ),
        if (vm.loading && !vm.loaded)
          const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView())
        else if (vm.errorMessage case final msg? when vm.items.isEmpty)
          Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: ErrorView(message: msg, onRetry: vm.refresh))
        else ...[
          const SizedBox(height: AppSpacing.xs),
          if (vm.loading) const LinearProgressIndicator(),
          CountLabel('${vm.total} serviço(s) encontrado(s)'),
          if (vm.items.isEmpty)
            EmptyView(
              icon: Icons.search_off,
              message: 'Nenhum resultado encontrado${f.query.isNotEmpty ? ' para “${f.query}”' : ''}.\n'
                  'Tente outras palavras ou ajuste os filtros.',
              action: f.isEmpty ? null : TextButton(onPressed: _clear, child: const Text('Limpar filtros')),
            )
          else
            for (final s in vm.items) _ServiceResult(service: s, onBook: () => _book(s)),
          LoadMoreButton(visible: vm.hasMore, loading: vm.loadingMore, onPressed: _loadMore),
        ],
      ],
    );
  }
}

class _ServiceResult extends StatelessWidget {
  const _ServiceResult({required this.service, required this.onBook});

  final ServiceModel service;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = service;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar.named(name: s.providerName, photoUrl: s.providerPhotoUrl, radius: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text('${s.providerName} · ${s.category}', style: theme.textTheme.bodySmall),
                  if (s.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(s.description, style: theme.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.md,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(Fmt.brl(s.price), style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      )),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text(Fmt.duration(s.durationMin), style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: onBook,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              child: const Text('Agendar'),
            ),
          ],
        ),
      ),
    );
  }
}

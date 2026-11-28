import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/catalog_models.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../home/app_navigator.dart';
import '../../home/viewmodels/home_navigation.dart';
import '../../search/viewmodels/search_view_model.dart';
import 'booking_screen.dart';

/// Busca do cliente (tela "Usua 3"): profissionais, nota, Conversar / Agendar.
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  late final TextEditingController _query;
  late final TextEditingController _maxPrice;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    final vm = context.read<SearchViewModel>();
    _query = TextEditingController(text: vm.filters.query);
    _maxPrice = TextEditingController(text: vm.filters.maxPrice?.toStringAsFixed(0) ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.loadCategories();
      if (!vm.loaded && !vm.loading) vm.refresh();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  void _clear(SearchViewModel vm) {
    _query.clear();
    _maxPrice.clear();
    vm.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final c = context.bikoColors;
    final f = vm.filters;
    // A tela inicial pode ter trocado o texto da busca.
    if (_query.text.trim() != f.query && !FocusScope.of(context).hasFocus) _query.text = f.query;
    if (vm.takeLoadMoreError() case final msg?) {
      WidgetsBinding.instance.addPostFrameCallback((_) => showAppSnackBar(context, msg, error: true));
    }

    return BikoPage(
      onRefresh: vm.refresh,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.page, MediaQuery.paddingOf(context).top + 18, AppSpacing.page, 12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 42,
                child: Material(
                  color: c.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.line)),
                  child: IconButton(
                    tooltip: 'Voltar',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.read<HomeNavigation>().goTo(AppTab.home),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _query,
                  maxLength: 80,
                  textInputAction: TextInputAction.search,
                  onChanged: vm.setQuery,
                  onSubmitted: vm.setQuery,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: f.category.isNotEmpty ? f.category : 'O que você procura?',
                    fillColor: c.card,
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        ChipRow(
          children: [
            BikoChip(label: 'Filtros', soft: true, icon: Icons.tune, onTap: () => setState(() => _showFilters = !_showFilters)),
            BikoChip(label: 'Menor Preço', selected: f.sort == SearchSort.priceAsc, onTap: () => vm.toggleSort(SearchSort.priceAsc)),
            BikoChip(label: 'Melhor Nota ⭐', selected: f.sort == SearchSort.rating, onTap: () => vm.toggleSort(SearchSort.rating)),
            if (f.category.isNotEmpty) BikoChip(label: '${f.category} ✕', selected: true, onTap: () => vm.setCategory('')),
          ],
        ),
        if (_showFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 0),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: f.category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Todas as categorias')),
                    for (final s in CategoryStyle.all) DropdownMenuItem(value: s.name, child: Text(s.name)),
                  ],
                  onChanged: (v) => vm.setCategory(v ?? ''),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _maxPrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                  decoration: const InputDecoration(labelText: 'Preço máximo (R\$)'),
                  onChanged: (t) => vm.setMaxPrice(Fmt.parseMoney(t)),
                ),
              ],
            ),
          ),
        SectionHeader(
          'Profissionais disponíveis',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, size: 18, color: c.green),
              Text('${vm.total} encontrado(s)', style: TextStyle(color: c.green, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ],
          ),
        ),
        if (vm.loading && vm.items.isEmpty)
          const SizedBox(height: 240, child: LoadingView())
        else if (vm.errorMessage case final msg? when vm.items.isEmpty)
          SizedBox(height: 260, child: ErrorView(message: msg, onRetry: vm.refresh))
        else if (vm.items.isEmpty)
          EmptyText(
            'Nenhum resultado encontrado${f.query.isNotEmpty ? ' para “${f.query}”' : ''}.\nTente outras palavras ou ajuste os filtros.',
            action: LinkText('Limpar filtros', onTap: () => _clear(vm)),
          )
        else ...[
          for (var i = 0; i < vm.items.length; i++)
            _ResultCard(service: vm.items[i], best: i == 0 && vm.items[i].providerRating != null && vm.items.length > 1),
          LoadMoreButton(visible: vm.hasMore, loading: vm.loadingMore, onPressed: vm.loadMore),
        ],
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.service, required this.best});

  final ServiceModel service;

  /// Primeiro da lista com nota: "MAIS BEM AVALIADO".
  final bool best;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final s = service;
    final card = BikoCard(
      highlight: best,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => openProvider(context, s.providerId),
            child: Row(
              children: [
                BikoAvatar(name: s.providerName, photoUrl: s.providerPhotoUrl, size: 60, square: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              s.providerName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.ink),
                            ),
                          ),
                          if (s.providerVerified) ...[const SizedBox(width: 6), const VerifiedIcon()],
                        ],
                      ),
                      Text(s.providerSpecialty ?? s.category, style: TextStyle(color: c.muted, fontSize: 13.5)),
                      const SizedBox(height: 4),
                      RatingLine(rating: s.providerRating, count: s.providerReviews),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const ThinDivider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title, style: TextStyle(color: c.muted, fontSize: 12.5)),
                    Text(Fmt.brl(s.price), style: TextStyle(color: c.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 15, color: c.green),
                      const SizedBox(width: 4),
                      Text(Fmt.duration(s.durationMin), style: TextStyle(color: c.green, fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ],
                  ),
                  Text('Disponível hoje', style: TextStyle(color: c.muted, fontSize: 12.5)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ButtonPair(
            left: BikoButton(
              label: 'Conversar',
              icon: Icons.chat_bubble_outline,
              style: BikoButtonStyle.light,
              onPressed: () => openChat(context, s.providerId),
            ),
            right: BikoButton(
              label: 'Agendar',
              icon: Icons.event_available_outlined,
              onPressed: () => pushScreen<void>(context, BookingScreen(service: s)),
            ),
          ),
        ],
      ),
    );
    if (!best) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: 6), child: card),
        Positioned(
          top: -4,
          right: 32,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: c.orange, borderRadius: BorderRadius.circular(8)),
            child: const Text(
              'MAIS BEM AVALIADO',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}

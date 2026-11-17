import 'dart:async';

import '../../../core/errors/app_exception.dart';
import '../../../core/viewmodel/paged_list_view_model.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/paged.dart';
import '../../../data/remote/catalog_service.dart';

/// Aba "Buscar" do cliente: texto livre, categoria, preço máximo e ordenação.
class SearchViewModel extends PagedListViewModel<ServiceModel> {
  SearchViewModel(this._service);

  static const Duration debounce = Duration(milliseconds: 300);

  final CatalogService _service;
  SearchFilters _filters = const SearchFilters();
  List<CategoryModel> _categories = const [];
  Timer? _timer;

  SearchFilters get filters => _filters;
  List<CategoryModel> get categories => _categories;

  /// Categorias do filtro (carregadas uma vez).
  Future<void> loadCategories() async {
    if (_categories.isNotEmpty) return;
    try {
      _categories = await _service.categories();
      notify();
    } on AppException {
      // Sem categorias o filtro só mostra "Todas"; a busca continua funcionando.
    }
  }

  void _apply(SearchFilters next, {bool debounced = false}) {
    _filters = next;
    _timer?.cancel();
    if (debounced) {
      notify();
      _timer = Timer(debounce, refresh);
    } else {
      refresh();
    }
  }

  /// Digitação: espera o usuário parar de digitar antes de buscar.
  void setQuery(String text) {
    final q = text.trim();
    if (q == _filters.query) return;
    _apply(_filters.copyWith(query: q), debounced: true);
  }

  void setMaxPrice(double? value) {
    if (value == _filters.maxPrice) return;
    _apply(_filters.copyWith(maxPrice: () => value), debounced: true);
  }

  void setCategory(String category, {bool reload = true}) {
    _filters = _filters.copyWith(category: category);
    if (reload) {
      _apply(_filters);
    } else {
      notify();
    }
  }

  void setSort(SearchSort sort) => _apply(_filters.copyWith(sort: sort));

  void clearFilters() => _apply(const SearchFilters());

  @override
  Future<Paged<ServiceModel>> fetchPage(int offset) => _service.search(_filters, offset: offset);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

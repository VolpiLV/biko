import '../../data/models/paged.dart';
import '../errors/app_exception.dart';
import 'base_view_model.dart';

/// Lista paginada com "Carregar mais": primeira página, próximas páginas,
/// estados de carregando/erro e proteção contra respostas atrasadas.
abstract class PagedListViewModel<T> extends BaseViewModel {
  List<T> _items = const [];
  int _total = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loaded = false;
  String? _errorMessage;
  String? _loadMoreError;
  int _generation = 0;

  List<T> get items => _items;
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;

  /// Já carregou a primeira página pelo menos uma vez.
  bool get loaded => _loaded;
  String? get errorMessage => _errorMessage;

  /// Erro ao carregar a próxima página (a lista atual continua na tela).
  String? takeLoadMoreError() {
    final e = _loadMoreError;
    _loadMoreError = null;
    return e;
  }

  /// Busca uma página a partir de [offset] com os filtros atuais.
  Future<Paged<T>> fetchPage(int offset);

  /// Recarrega do zero (ex.: filtro mudou, voltou para a aba, depois de salvar).
  Future<void> refresh() async {
    final gen = ++_generation;
    _loading = true;
    _loadingMore = false; // um "carregar mais" antigo é descartado
    _errorMessage = null;
    notify();
    try {
      final page = await fetchPage(0);
      if (gen != _generation) return; // filtro mudou enquanto carregava
      _items = page.items;
      _total = page.total;
      _hasMore = page.hasMore;
      _loaded = true;
    } on AppException catch (e) {
      if (gen != _generation) return;
      _errorMessage = e.message;
    }
    _loading = false;
    notify();
  }

  Future<void> loadMore() async {
    if (_loadingMore || _loading || !_hasMore) return;
    final gen = _generation;
    _loadingMore = true;
    notify();
    try {
      final page = await fetchPage(_items.length);
      if (gen != _generation) return;
      _items = [..._items, ...page.items];
      _total = page.total;
      _hasMore = page.hasMore;
    } on AppException catch (e) {
      if (gen == _generation) _loadMoreError = e.message;
    } finally {
      if (gen == _generation) {
        _loadingMore = false;
        notify();
      }
    }
  }
}

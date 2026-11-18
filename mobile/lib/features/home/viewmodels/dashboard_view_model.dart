import '../../../core/errors/app_exception.dart';
import '../../../core/viewmodel/base_view_model.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/dashboard_models.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/user_role.dart';
import '../../../data/remote/admin_service.dart';
import '../../../data/remote/catalog_service.dart';
import '../../../data/remote/order_service.dart';

/// Aba "Início": o conteúdo depende do perfil.
/// Cliente -> categorias; prestador -> painel; admin -> resumo.
class DashboardViewModel extends BaseViewModel {
  DashboardViewModel({
    required this.role,
    required CatalogService catalog,
    required OrderService orders,
    required AdminService admin,
  })  : _catalog = catalog,
        _orders = orders,
        _admin = admin;

  final UserRole role;
  final CatalogService _catalog;
  final OrderService _orders;
  final AdminService _admin;

  bool _loading = false;
  String? _errorMessage;
  List<CategoryModel> _categories = const [];
  List<OrderModel> _notices = const [];
  ProviderPanel? _panel;
  AdminSummary? _summary;

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  List<CategoryModel> get categories => _categories;

  /// Cliente: pedidos que o prestador adiou (aviso de atraso).
  List<OrderModel> get notices => _notices;
  ProviderPanel? get panel => _panel;
  AdminSummary? get summary => _summary;

  bool get hasData => switch (role) {
        UserRole.cliente => _categories.isNotEmpty,
        UserRole.prestador => _panel != null,
        UserRole.admin => _summary != null,
      };

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    notify();
    try {
      switch (role) {
        case UserRole.cliente:
          final home = await _catalog.clientHome();
          _categories = home.categories;
          _notices = home.notices;
        case UserRole.prestador:
          _panel = await _orders.providerPanel();
        case UserRole.admin:
          _summary = await _admin.summary();
      }
    } on AppException catch (e) {
      _errorMessage = e.message;
    }
    _loading = false;
    notify();
  }
}

import '../../../core/errors/app_exception.dart';
import '../../../core/viewmodel/base_view_model.dart';
import '../../../core/viewmodel/form_view_model.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/remote/catalog_service.dart';

/// Aba "Serviços" do prestador: o que ele oferece (é o que aparece na busca do cliente).
class MyServicesViewModel extends BaseViewModel {
  MyServicesViewModel(this._service);

  final CatalogService _service;

  List<ServiceModel> _services = const [];
  List<CategoryModel> _categories = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _errorMessage;

  List<ServiceModel> get services => _services;
  List<CategoryModel> get categories => _categories;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    notify();
    try {
      final results = await Future.wait([
        _service.myServices(),
        if (_categories.isEmpty) _service.categories(),
      ]);
      _services = results[0] as List<ServiceModel>;
      if (results.length > 1) _categories = results[1] as List<CategoryModel>;
      _loaded = true;
    } on AppException catch (e) {
      _errorMessage = e.message;
    }
    _loading = false;
    notify();
  }
}

/// Formulário de criar/editar serviço.
class ServiceFormViewModel extends FormViewModel {
  ServiceFormViewModel(this._service, {this.editing});

  final CatalogService _service;

  /// null = novo serviço.
  final ServiceModel? editing;

  bool get isNew => editing == null;

  static const List<int> durations = [30, 45, 60, 90, 120, 150, 180, 240, 300, 360, 480];

  Future<ServiceModel?> save(ServiceInput input) {
    final current = editing;
    return submit(
      () => current == null ? _service.createService(input) : _service.updateService(current.id, input),
    );
  }
}

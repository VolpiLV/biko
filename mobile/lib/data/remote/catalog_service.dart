import '../../core/network/api_client.dart';
import '../../core/utils/json_reader.dart';
import '../models/catalog_models.dart';
import '../models/paged.dart';

/// Categorias, busca, serviços do prestador e agenda.
class CatalogService {
  const CatalogService(this._api);

  final ApiClient _api;

  Future<List<CategoryModel>> categories() => _api.get(
        '/api/categories',
        (json) => readList(json, 'categories', CategoryModel.fromJson),
      );

  /// Tela inicial do cliente: categorias com a contagem de serviços.
  Future<List<CategoryModel>> clientHome() => _api.get(
        '/api/cliente/home',
        (json) => readList(json, 'categorias', CategoryModel.fromJson),
      );

  Future<Paged<ServiceModel>> search(SearchFilters filters, {int offset = 0}) => _api.get(
        '/api/search',
        (json) => Paged.fromSearch(json, ServiceModel.fromJson),
        query: {...filters.toQuery(), if (offset > 0) 'offset': offset},
      );

  Future<List<ServiceModel>> myServices() => _api.get(
        '/api/services/mine',
        (json) => readList(json, 'services', ServiceModel.fromJson),
      );

  Future<ServiceModel> createService(ServiceInput input) => _api.post(
        '/api/services',
        (json) => ServiceModel.fromJson(readMap(json, 'service')),
        body: input.toJson(),
      );

  Future<ServiceModel> updateService(int id, ServiceInput input) => _api.patch(
        '/api/services/$id',
        (json) => ServiceModel.fromJson(readMap(json, 'service')),
        body: input.toJson(),
      );

  /// Horários já ocupados do prestador no dia ("AAAA-MM-DD").
  Future<List<BusySlot>> providerAgenda(int providerId, String date) => _api.get(
        '/api/providers/$providerId/agenda',
        (json) => readList(json, 'busy', BusySlot.fromJson),
        query: {'date': date},
      );
}

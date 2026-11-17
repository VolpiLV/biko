import '../../core/network/api_client.dart';
import '../../core/utils/json_reader.dart';
import '../models/dashboard_models.dart';
import '../models/paged.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

/// Filtros da lista de usuários do admin.
class UserFilters {
  const UserFilters({this.search = '', this.role, this.active});

  final String search;
  final UserRole? role;

  /// null = qualquer status.
  final bool? active;

  Map<String, Object?> toQuery() => {
        if (search.isNotEmpty) 'search': search,
        if (role != null) 'role': role!.apiValue,
        if (active != null) 'status': active! ? 'ativo' : 'inativo',
      };
}

/// Gestão de usuários e resumo (somente admin).
class AdminService {
  const AdminService(this._api);

  final ApiClient _api;

  Future<AdminSummary> summary() => _api.get('/api/admin/resumo', AdminSummary.fromJson);

  Future<Paged<UserModel>> users(UserFilters filters, {int offset = 0}) => _api.get(
        '/api/users',
        (json) => Paged.fromJson(json, 'users', UserModel.fromJson),
        query: {...filters.toQuery(), if (offset > 0) 'offset': offset},
      );

  Future<UserModel> createUser({
    required String name,
    required String email,
    required String phone,
    required UserRole role,
    required String password,
  }) =>
      _api.post(
        '/api/users',
        (json) => UserModel.fromJson(readMap(json, 'user')),
        body: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'phone': phone.trim(),
          'role': role.apiValue,
          'password': password,
        },
      );

  /// [role] e [active] ficam de fora quando o admin edita a própria conta.
  Future<UserModel> updateUser(
    int id, {
    required String name,
    required String email,
    required String phone,
    UserRole? role,
    bool? active,
  }) =>
      _api.patch(
        '/api/users/$id',
        (json) => UserModel.fromJson(readMap(json, 'user')),
        body: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'phone': phone.trim(),
          if (role != null) 'role': role.apiValue,
          'active': ?active,
        },
      );
}

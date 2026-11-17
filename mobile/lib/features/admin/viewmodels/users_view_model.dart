import 'dart:async';

import '../../../core/viewmodel/form_view_model.dart';
import '../../../core/viewmodel/paged_list_view_model.dart';
import '../../../data/models/paged.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_role.dart';
import '../../../data/remote/admin_service.dart';

/// Aba "Usuários" do admin: busca por nome/e-mail, filtro por perfil e status.
class UsersViewModel extends PagedListViewModel<UserModel> {
  UsersViewModel(this._service);

  final AdminService _service;
  UserFilters _filters = const UserFilters();
  Timer? _timer;

  UserFilters get filters => _filters;

  void setSearch(String text) {
    final s = text.trim();
    if (s == _filters.search) return;
    _filters = UserFilters(search: s, role: _filters.role, active: _filters.active);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), refresh);
  }

  void setRole(UserRole? role) {
    _filters = UserFilters(search: _filters.search, role: role, active: _filters.active);
    refresh();
  }

  void setActive(bool? active) {
    _filters = UserFilters(search: _filters.search, role: _filters.role, active: active);
    refresh();
  }

  @override
  Future<Paged<UserModel>> fetchPage(int offset) => _service.users(_filters, offset: offset);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Formulário de criar/editar usuário (admin).
class UserFormViewModel extends FormViewModel {
  UserFormViewModel(this._service, {this.editing, required this.currentUserId});

  final AdminService _service;
  final UserModel? editing;
  final int currentUserId;

  bool get isNew => editing == null;

  /// O admin não pode desativar nem tirar o perfil de admin da própria conta.
  bool get isSelf => editing?.id == currentUserId;

  Future<UserModel?> save({
    required String name,
    required String email,
    required String phone,
    required UserRole role,
    required bool active,
    String password = '',
  }) {
    final current = editing;
    return submit(() {
      if (current == null) {
        return _service.createUser(name: name, email: email, phone: phone, role: role, password: password);
      }
      return _service.updateUser(
        current.id,
        name: name,
        email: email,
        phone: phone,
        role: isSelf ? null : role,
        active: isSelf ? null : active,
      );
    });
  }
}

/// Perfis do Biko. [apiValue] é o texto usado pelo backend.
enum UserRole {
  admin('admin', 'Admin'),
  cliente('cliente', 'Cliente'),
  prestador('prestador', 'Prestador');

  const UserRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static UserRole fromApi(Object? value) {
    for (final role in UserRole.values) {
      if (role.apiValue == value) return role;
    }
    throw FormatException('Perfil de usuário desconhecido: $value');
  }
}

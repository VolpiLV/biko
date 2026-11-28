import '../../core/utils/json_reader.dart';
import 'user_role.dart';

/// Usuário como a API devolve (`publicUser` no server.js).
/// toJson/fromJson = API REST; toMap/fromMap = banco local (SQLite).
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.phone,
    this.createdAt,
    this.photoUrl,
    this.specialty,
    this.visitPrice,
    this.online = true,
    this.categories,
    this.verified = false,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final bool active;
  final DateTime? createdAt;

  /// Caminho relativo na API (ex.: /api/photo/3?v=2). Nulo quando não há foto.
  final String? photoUrl;

  // ---- perfil profissional (só vem para prestador) ----
  /// Ex.: "Especialista em Telhados e Coberturas".
  final String? specialty;

  /// Valor base da visita técnica.
  final double? visitPrice;

  /// Offline: os serviços dele somem da busca.
  final bool online;

  /// Categorias ligadas no perfil (null = todas).
  final List<String>? categories;

  /// CPF verificado no cadastro do profissional.
  final bool verified;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: readInt(json, 'id'),
        name: readString(json, 'name'),
        email: readString(json, 'email'),
        phone: readStringOrNull(json, 'phone'),
        role: UserRole.fromApi(json['role']),
        active: readBool(json, 'active'),
        createdAt: readServerDateOrNull(json, 'created_at'),
        photoUrl: readStringOrNull(json, 'photo_url'),
        specialty: readStringOrNull(json, 'specialty'),
        visitPrice: readNumOrNull(json, 'visit_price'),
        online: json['online'] != false,
        categories: readStringListOrNull(json, 'categories'),
        verified: json['verified'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.apiValue,
        'active': active,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'photo_url': photoUrl,
      };

  /// SQLite não tem bool nem DateTime: active vira 0/1 e a data vira epoch em ms (UTC).
  factory UserModel.fromMap(Map<String, Object?> map) {
    final createdAtMs = map['created_at'];
    return UserModel(
      id: readInt(map, 'id'),
      name: readString(map, 'name'),
      email: readString(map, 'email'),
      phone: readStringOrNull(map, 'phone'),
      role: UserRole.fromApi(map['role']),
      active: readBool(map, 'active'),
      createdAt: createdAtMs is int
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true)
          : null,
      photoUrl: readStringOrNull(map, 'photo_url'),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.apiValue,
        'active': active ? 1 : 0,
        'created_at': createdAt?.millisecondsSinceEpoch,
        'photo_url': photoUrl,
      };

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

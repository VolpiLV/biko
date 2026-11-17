import 'dart:convert';
import 'dart:typed_data';

import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_reader.dart';
import '../models/user_model.dart';

/// Conta do próprio usuário: dados, senha e foto. Também a recuperação de senha.
class ProfileService {
  const ProfileService(this._api);

  final ApiClient _api;

  static UserModel _user(Map<String, dynamic> json) => UserModel.fromJson(readMap(json, 'user'));

  /// Trocar o e-mail exige a senha atual ([currentPassword]).
  Future<UserModel> updateMe({
    required String name,
    required String email,
    required String phone,
    String? currentPassword,
  }) =>
      _api.patch(
        '/api/me',
        _user,
        body: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'phone': phone.trim(),
          if (currentPassword != null && currentPassword.isNotEmpty)
            'currentPassword': currentPassword,
        },
      );

  /// Retorna a mensagem de sucesso do servidor.
  Future<String> changePassword({required String current, required String next}) => _api.post(
        '/api/me/password',
        (json) => readStringOrNull(json, 'message') ?? 'Senha alterada com sucesso.',
        body: {'currentPassword': current, 'newPassword': next},
      );

  /// Envia a foto como data URL (o servidor confere o tipo real pelos bytes).
  Future<UserModel> uploadPhoto(Uint8List bytes) {
    final mime = sniffImageMime(bytes);
    if (mime == null) {
      throw const AppException(AppErrorKind.validation, 'Escolha uma imagem PNG, JPG ou WEBP.');
    }
    return _api.put(
      '/api/me/photo',
      _user,
      body: {'image': 'data:$mime;base64,${base64Encode(bytes)}'},
    );
  }

  Future<UserModel> removePhoto() => _api.delete('/api/me/photo', _user);

  /// Esqueci a senha. Em desenvolvimento o servidor devolve o código em `devToken`.
  Future<({String message, String? devToken})> forgotPassword(String email) => _api.post(
        '/api/auth/forgot',
        (json) => (
          message: readString(json, 'message'),
          devToken: readStringOrNull(json, 'devToken'),
        ),
        body: {'email': email.trim().toLowerCase()},
      );

  Future<String> resetPassword({required String token, required String password}) => _api.post(
        '/api/auth/reset',
        (json) => readStringOrNull(json, 'message') ?? 'Senha redefinida. Faça login.',
        body: {'token': token.trim(), 'password': password},
      );
}

/// Descobre o tipo da imagem pelos primeiros bytes (mesma regra do servidor).
String? sniffImageMime(Uint8List b) {
  if (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
    return 'image/png';
  }
  if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  if (b.length > 12 &&
      ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

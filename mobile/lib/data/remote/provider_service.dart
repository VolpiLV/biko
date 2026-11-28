import 'dart:convert';
import 'dart:typed_data';

import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_reader.dart';
import '../models/provider_models.dart';
import '../models/user_model.dart';
import 'profile_service.dart';

/// Perfil profissional, portfólio e carteira do prestador.
class ProviderService {
  const ProviderService(this._api);

  final ApiClient _api;

  static ProviderProfile _profile(Map<String, dynamic> json) => ProviderProfile.fromJson(readMap(json, 'prestador'));

  /// Perfil público (o cliente abre pela busca).
  Future<ProviderProfile> publicProfile(int providerId) => _api.get('/api/prestadores/$providerId', _profile);

  /// "Meu Perfil Profissional".
  Future<ProviderProfile> myProfile() => _api.get('/api/me/profissional', _profile);

  /// Atualiza especialidade, valor da visita, online/offline ou categorias.
  /// Só os campos informados são enviados.
  Future<({UserModel user, ProviderProfile profile})> update({
    String? specialty,
    String? visitPrice,
    bool? online,
    List<String>? categories,
  }) =>
      _api.patch(
        '/api/me/profissional',
        (json) => (user: UserModel.fromJson(readMap(json, 'user')), profile: _profile(json)),
        body: {
          'specialty': ?specialty,
          'visit_price': ?visitPrice,
          'online': ?online,
          'categories': ?categories,
        },
      );

  Future<void> addPortfolioPhoto(Uint8List bytes) {
    final mime = sniffImageMime(bytes);
    if (mime == null) {
      throw const AppException(AppErrorKind.validation, 'Escolha uma imagem PNG, JPG ou WEBP.');
    }
    return _api.post<void>('/api/me/portfolio', (_) {}, body: {'image': 'data:$mime;base64,${base64Encode(bytes)}'});
  }

  Future<void> removePortfolioPhoto(int id) => _api.delete<void>('/api/me/portfolio/$id', (_) {});

  Future<Wallet> wallet() => _api.get('/api/carteira', Wallet.fromJson);

  /// Saque via Pix (simulado). Devolve a carteira atualizada e a mensagem.
  Future<({Wallet wallet, String message})> withdraw(String amount) => _api.post(
        '/api/carteira/saque',
        (json) => (wallet: Wallet.fromJson(json), message: readStringOrNull(json, 'mensagem') ?? 'Transferência enviada.'),
        body: {'valor': amount},
      );
}

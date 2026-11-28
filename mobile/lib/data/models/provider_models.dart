import '../../core/utils/json_reader.dart';
import 'catalog_models.dart';

/// Avaliação mostrada no perfil do prestador.
class ProviderReview {
  const ProviderReview({required this.stars, required this.clientName, this.comment});

  final int stars;
  final String clientName;
  final String? comment;

  factory ProviderReview.fromJson(Map<String, dynamic> json) => ProviderReview(
        stars: readInt(json, 'stars'),
        clientName: readStringOrNull(json, 'client_name') ?? 'Cliente',
        comment: readStringOrNull(json, 'comment'),
      );
}

/// Foto do portfólio. A URL exige o token (é baixada pelo ApiClient).
class PortfolioPhoto {
  const PortfolioPhoto({required this.id, required this.url});

  final int id;
  final String url;

  factory PortfolioPhoto.fromJson(Map<String, dynamic> json) =>
      PortfolioPhoto(id: readInt(json, 'id'), url: readString(json, 'url'));
}

/// Perfil do prestador (`perfilPublico` no server.js): é o que o cliente vê e
/// também a tela "Meu Perfil Profissional".
class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.name,
    required this.services,
    required this.portfolio,
    required this.reviews,
    this.photoUrl,
    this.specialty,
    this.online = true,
    this.verified = false,
    this.visitPrice,
    this.categories,
    this.rating,
    this.reviewsCount = 0,
  });

  final int id;
  final String name;
  final String? photoUrl;
  final String? specialty;
  final bool online;
  final bool verified;
  final double? visitPrice;

  /// null = todas as categorias ligadas.
  final List<String>? categories;
  final double? rating;
  final int reviewsCount;
  final List<ProviderReview> reviews;
  final List<ServiceModel> services;
  final List<PortfolioPhoto> portfolio;

  static const int maxPortfolio = 6;

  bool categoryOn(String name) => categories == null || categories!.contains(name);

  factory ProviderProfile.fromJson(Map<String, dynamic> json) {
    final id = readInt(json, 'id');
    final name = readString(json, 'name');
    final photo = readStringOrNull(json, 'photo_url');
    return ProviderProfile(
      id: id,
      name: name,
      photoUrl: photo,
      specialty: readStringOrNull(json, 'specialty'),
      online: json['online'] != false,
      verified: json['verified'] == true,
      visitPrice: readNumOrNull(json, 'visit_price'),
      categories: readStringListOrNull(json, 'categories'),
      rating: readNumOrNull(json, 'rating'),
      reviewsCount: readNumOrNull(json, 'reviews_count')?.round() ?? 0,
      reviews: readList(json, 'reviews', ProviderReview.fromJson),
      services: [
        for (final s in readList(json, 'services', ServiceModel.fromProfile))
          s.withProvider(id: id, name: name, photoUrl: photo),
      ],
      portfolio: readList(json, 'portfolio', PortfolioPhoto.fromJson),
    );
  }
}

/// Linha do histórico da carteira: entrada (pagamento de cliente) ou saque.
class WalletEntry {
  const WalletEntry({required this.isWithdrawal, required this.title, required this.amount, required this.when, this.released = true});

  final bool isWithdrawal;
  final String title;
  final double amount;
  final DateTime when;

  /// Entrada já liberada (o serviço foi concluído).
  final bool released;

  factory WalletEntry.fromJson(Map<String, dynamic> json) => WalletEntry(
        isWithdrawal: json['tipo'] == 'saque',
        title: readString(json, 'titulo'),
        amount: readNum(json, 'valor'),
        when: DateTime.fromMillisecondsSinceEpoch(readNum(json, 'quando').round()),
        released: json['liberado'] != false,
      );
}

/// "Ganhos e Carteira" do prestador (SIMULADO).
class Wallet {
  const Wallet({required this.available, required this.pending, required this.thisMonth, required this.history, required this.pixKey});

  final double available;
  final double pending;
  final double thisMonth;
  final List<WalletEntry> history;
  final String pixKey;

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        available: readNum(json, 'disponivel'),
        pending: readNum(json, 'pendente'),
        thisMonth: readNum(json, 'este_mes'),
        history: readList(json, 'historico', WalletEntry.fromJson),
        pixKey: readStringOrNull(json, 'chave_pix') ?? '',
      );
}

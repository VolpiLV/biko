import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/provider_models.dart';
import '../../../data/remote/provider_service.dart';
import '../../../shared/widgets/auth_image.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../home/app_navigator.dart';
import '../../provider/viewmodels/provider_view_models.dart';
import 'booking_screen.dart';

/// Perfil público do prestador (visto pelo cliente): serviços, portfólio e avaliações.
class ProviderPublicScreen extends StatelessWidget {
  const ProviderPublicScreen({super.key, required this.providerId});

  final int providerId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => ProviderProfileViewModel(context.read<ProviderService>(), providerId: providerId)..load(),
        child: const _ProviderView(),
      );
}

class _ProviderView extends StatelessWidget {
  const _ProviderView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProviderProfileViewModel>();
    final p = vm.profile;
    return Scaffold(
      appBar: bikoAppBar(context, 'Profissional'),
      body: p == null
          ? (vm.loading ? const LoadingView() : ErrorView(message: vm.error ?? 'Profissional não encontrado.', onRetry: vm.load))
          : BikoPage(
              onRefresh: vm.load,
              children: [
                const SizedBox(height: 10),
                ProfileHeadCard(profile: p, actions: _actions(context, p)),
                BikoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CardTitle('Serviços'),
                      if (p.services.isEmpty)
                        Text('Nenhum serviço disponível agora.', style: TextStyle(color: context.bikoColors.muted, fontSize: 12.5))
                      else
                        for (final s in p.services)
                          ServiceLine(
                            service: s,
                            trailing: BikoButton(label: 'Agendar', small: true, expand: false, onPressed: () => _book(context, s)),
                          ),
                    ],
                  ),
                ),
                if (p.portfolio.isNotEmpty)
                  BikoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [const CardTitle('Portfólio de Trabalhos'), PortfolioGrid(photos: p.portfolio)],
                    ),
                  ),
                if (p.reviews.isNotEmpty) ReviewsCard(reviews: p.reviews),
              ],
            ),
    );
  }

  void _book(BuildContext context, ServiceModel s) => pushScreen<void>(context, BookingScreen(service: s));

  Widget _actions(BuildContext context, ProviderProfile p) => ButtonPair(
        left: BikoButton(
          label: 'Conversar',
          icon: Icons.chat_bubble_outline,
          style: BikoButtonStyle.light,
          onPressed: () => openChat(context, p.id),
        ),
        right: BikoButton(
          label: 'Agendar',
          icon: Icons.event_available_outlined,
          onPressed: p.services.isEmpty ? null : () => _book(context, p.services.first),
        ),
      );
}

/// Cabeçalho do perfil: foto com anel, nome + verificado, especialidade e nota.
class ProfileHeadCard extends StatelessWidget {
  const ProfileHeadCard({super.key, required this.profile, this.actions, this.specialtyAction, this.emptyRating = 'Novo no Biko'});

  final ProviderProfile profile;
  final Widget? actions;

  /// "Editar" ao lado da especialidade (no próprio perfil).
  final Widget? specialtyAction;
  final String emptyRating;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final p = profile;
    return BikoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        children: [
          BikoAvatar(name: p.name, photoUrl: p.photoUrl, size: 92, ring: true),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  p.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.ink),
                ),
              ),
              if (p.verified) ...[const SizedBox(width: 6), const VerifiedIcon()],
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                p.specialty ?? (specialtyAction != null ? 'Toque em editar para escrever sua especialidade' : 'Prestador Biko'),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, fontSize: 13.5),
              ),
              ?specialtyAction,
            ],
          ),
          const SizedBox(height: 10),
          RatingPill(rating: p.rating, count: p.reviewsCount, emptyLabel: emptyRating),
          if (actions case final a?) ...[const SizedBox(height: 16), a],
        ],
      ),
    );
  }
}

/// Linha de serviço (`.svc-line`): título, categoria · duração, preço.
class ServiceLine extends StatelessWidget {
  const ServiceLine({super.key, required this.service, this.trailing});

  final ServiceModel service;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c.ink)),
                Text('${service.category} · ${Fmt.duration(service.durationMin)}', style: TextStyle(color: c.muted, fontSize: 12.5)),
              ],
            ),
          ),
          Text(Fmt.brl(service.price), style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
          if (trailing case final t?) ...[const SizedBox(width: 10), t],
        ],
      ),
    );
  }
}

/// Grade 3×N de fotos do portfólio. Com [onRemove], mostra o "×" de cada foto.
class PortfolioGrid extends StatelessWidget {
  const PortfolioGrid({super.key, required this.photos, this.onRemove, this.onAdd});

  final List<PortfolioPhoto> photos;
  final ValueChanged<PortfolioPhoto>? onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final tiles = <Widget>[
      for (final f in photos)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AuthImage(url: f.url, fallback: ColoredBox(color: c.neutralSoft)),
              if (onRemove != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onRemove!(f),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(Icons.close, size: 16, color: Colors.white, semanticLabel: 'Remover foto'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (onAdd != null && photos.length < ProviderProfile.maxPortfolio)
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.muted2, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Icon(Icons.add, color: c.muted), Text('Foto', style: TextStyle(color: c.muted, fontSize: 12))],
            ),
          ),
        ),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: tiles,
    );
  }
}

/// "O que dizem os clientes".
class ReviewsCard extends StatelessWidget {
  const ReviewsCard({super.key, required this.reviews});

  final List<ProviderReview> reviews;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return BikoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('O que dizem os clientes'),
          for (final r in reviews)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '★' * r.stars, style: const TextStyle(color: Color(0xFFF5A623))),
                        TextSpan(text: '  ${r.clientName.split(' ').first}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  if (r.comment case final cm? when cm.isNotEmpty) Text(cm, style: TextStyle(color: c.muted, fontSize: 13.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

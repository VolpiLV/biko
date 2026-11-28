import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/catalog_models.dart';
import '../../../data/models/provider_models.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/auth_image.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../account/views/account_tab.dart';
import '../../client/views/provider_public_screen.dart';
import '../../home/app_navigator.dart';
import '../viewmodels/provider_view_models.dart';
import 'my_services_screen.dart';

/// "Meu Perfil Profissional" (tela "Prest 8").
class ProfessionalProfileTab extends StatefulWidget {
  const ProfessionalProfileTab({super.key});

  @override
  State<ProfessionalProfileTab> createState() => _ProfessionalProfileTabState();
}

class _ProfessionalProfileTabState extends State<ProfessionalProfileTab> {
  final _visit = TextEditingController();
  String? _visitError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<ProviderProfileViewModel>();
      await vm.load();
      if (vm.profile?.visitPrice case final v?) _visit.text = Fmt.brl(v);
    });
  }

  @override
  void dispose() {
    _visit.dispose();
    super.dispose();
  }

  void _report(String? error, String ok) {
    if (!mounted) return;
    showAppSnackBar(context, error ?? ok, error: error != null);
  }

  Future<void> _editSpecialty(ProviderProfile p) async {
    final vm = context.read<ProviderProfileViewModel>();
    final ctl = TextEditingController(text: p.specialty ?? '');
    final value = await showBikoSheet<String>(
      context,
      (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle('Sua especialidade'),
          const SizedBox(height: 8),
          TextField(
            controller: ctl,
            maxLength: 60,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ex.: Especialista em Telhados e Coberturas'),
          ),
          const SizedBox(height: 12),
          ButtonPair(
            left: BikoButton(label: 'Cancelar', style: BikoButtonStyle.light, onPressed: () => Navigator.pop(sheet)),
            right: BikoButton(label: 'Salvar', onPressed: () => Navigator.pop(sheet, ctl.text)),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (value == null) return;
    _report(await vm.update(specialty: value), 'Especialidade salva.');
  }

  Future<void> _saveVisit() async {
    final vm = context.read<ProviderProfileViewModel>();
    // "R$ 1.234,50" -> "1234,50"
    final raw = _visit.text.replaceAll(RegExp(r'[^\d,.]'), '').replaceAll(RegExp(r'\.(?=\d{3})'), '');
    final error = await vm.update(visitPrice: raw);
    if (!mounted) return;
    setState(() => _visitError = error);
    if (error == null) {
      if (vm.profile?.visitPrice case final v?) _visit.text = Fmt.brl(v);
      showAppSnackBar(context, 'Valor da visita salvo.');
    }
  }

  Future<void> _addPhoto() async {
    final vm = context.read<ProviderProfileViewModel>();
    // Reduz no aparelho: a foto fica abaixo do limite de 200 KB do servidor.
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    _report(await vm.addPhoto(bytes), 'Foto adicionada ao portfólio.');
  }

  Future<void> _removePhoto(PortfolioPhoto f) async {
    final error = await context.read<ProviderProfileViewModel>().removePhoto(f.id);
    if (error == null) AuthImage.evict(f.url);
    _report(error, 'Foto removida.');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProviderProfileViewModel>();
    final c = context.bikoColors;
    final p = vm.profile;

    return BikoPage(
      onRefresh: vm.load,
      children: [
        PageTitle(
          'Meu Perfil Profissional',
          trailing: IconButton(
            tooltip: 'Configurações da conta',
            onPressed: () => pushScreen<void>(context, const AccountScreen()),
            icon: Icon(Icons.settings_outlined, color: c.muted),
          ),
        ),
        if (p == null)
          vm.loading
              ? const SizedBox(height: 300, child: LoadingView())
              : SizedBox(height: 300, child: ErrorView(message: vm.error ?? 'Não foi possível carregar.', onRetry: vm.load))
        else ...[
          if (vm.busy) const LinearProgressIndicator(minHeight: 2),
          ProfileHeadCard(
            profile: p,
            emptyRating: 'Ainda sem avaliações',
            specialtyAction: LinkText('Editar', onTap: () => _editSpecialty(p)),
          ),
          BikoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CardTitle('Suas Categorias de Atuação'),
                for (final s in CategoryStyle.all)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(width: 26, child: Text(s.emoji, textAlign: TextAlign.center)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s.name, style: const TextStyle(fontSize: 14.5))),
                        Switch(
                          value: p.categoryOn(s.name),
                          onChanged: vm.busy
                              ? null
                              : (on) async => _report(await vm.toggleCategory(s.name, on), on ? '${s.name} ligado.' : '${s.name} desligado.'),
                        ),
                      ],
                    ),
                  ),
                Text('Categoria desligada: seus serviços dela somem da busca.', style: TextStyle(color: c.muted, fontSize: 12.5)),
              ],
            ),
          ),
          BikoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CardTitle('Valor Base da Visita Técnica'),
                Text(
                  'Esse é o valor mínimo exibido para os clientes ao solicitar um diagnóstico.',
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _visit,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.R$ ]'))],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(hintText: 'R\$ 0,00', errorText: _visitError),
                      ),
                    ),
                    const SizedBox(width: 10),
                    BikoButton(label: 'Salvar', expand: false, onPressed: vm.busy ? null : _saveVisit),
                  ],
                ),
              ],
            ),
          ),
          BikoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitle(
                  'Meus Serviços',
                  trailing: LinkText(
                    'Gerenciar',
                    onTap: () async {
                      await pushScreen<void>(context, const MyServicesScreen());
                      await vm.load();
                    },
                  ),
                ),
                if (p.services.isEmpty)
                  Text('Nenhum serviço ativo. Toque em Gerenciar para cadastrar.', style: TextStyle(color: c.muted, fontSize: 12.5))
                else
                  for (final s in p.services) ServiceLine(service: s),
              ],
            ),
          ),
          BikoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitle(
                  'Portfólio de Trabalhos',
                  trailing: p.portfolio.length < ProviderProfile.maxPortfolio ? LinkText('+ Adicionar', onTap: vm.busy ? null : _addPhoto) : null,
                ),
                PortfolioGrid(photos: p.portfolio, onRemove: vm.busy ? null : _removePhoto, onAdd: vm.busy ? null : _addPhoto),
              ],
            ),
          ),
          if (p.reviews.isNotEmpty) ReviewsCard(reviews: p.reviews),
        ],
      ],
    );
  }
}

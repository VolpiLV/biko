import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/remote/catalog_service.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../services/viewmodels/my_services_view_model.dart';
import '../../services/views/services_tab.dart';

/// "Meus Serviços": criar, editar e ativar/desativar (aberto pela Agenda e pelo Perfil).
class MyServicesScreen extends StatelessWidget {
  const MyServicesScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => MyServicesViewModel(context.read<CatalogService>()),
        child: Scaffold(appBar: bikoAppBar(context, 'Meus Serviços'), body: const ServicesTab()),
      );
}

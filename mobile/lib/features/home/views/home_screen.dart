import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/notifications/system_notifications.dart';
import '../../../core/theme/biko_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_role.dart';
import '../../../data/remote/admin_service.dart';
import '../../../data/remote/catalog_service.dart';
import '../../../data/remote/chat_service.dart';
import '../../../data/remote/notification_service.dart';
import '../../../data/remote/order_service.dart';
import '../../../data/remote/payment_service.dart';
import '../../../data/remote/provider_service.dart';
import '../../../shared/widgets/state_views.dart';
import '../../account/views/account_tab.dart';
import '../../admin/viewmodels/users_view_model.dart';
import '../../admin/views/admin_home_tab.dart';
import '../../admin/views/users_tab.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../chat/viewmodels/chat_view_models.dart';
import '../../chat/views/chats_tab.dart';
import '../../client/views/client_agenda_tab.dart';
import '../../client/views/client_home_tab.dart';
import '../../client/views/search_tab.dart';
import '../../notifications/viewmodels/notifications_view_model.dart';
import '../../notifications/widgets/notification_popups.dart';
import '../../payments/viewmodels/sales_view_model.dart';
import '../../payments/views/sales_tab.dart';
import '../../provider/viewmodels/provider_view_models.dart';
import '../../provider/views/professional_profile_tab.dart';
import '../../provider/views/provider_agenda_tab.dart';
import '../../provider/views/provider_home_tab.dart';
import '../../provider/views/provider_orders_screen.dart';
import '../../provider/views/wallet_tab.dart';
import '../../search/viewmodels/search_view_model.dart';
import '../viewmodels/dashboard_view_model.dart';
import '../viewmodels/home_navigation.dart';
import '../widgets/tab_back_handler.dart';

/// Área logada: abas conforme o perfil (cliente, prestador ou admin), como no Figma.
/// Os ViewModels das abas vivem aqui, então filtros e listas não se perdem ao trocar de aba.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<SessionViewModel, UserModel?>((s) => s.user);
    // Durante a troca de rota após o logout o usuário já é nulo por um instante.
    if (user == null) return const Scaffold(body: LoadingView());

    final catalog = context.read<CatalogService>();
    final orders = context.read<OrderService>();
    final admin = context.read<AdminService>();
    final providers = context.read<ProviderService>();
    final session = context.read<SessionViewModel>();

    return MultiProvider(
      // Outro usuário (ou perfil alterado) = estado novo.
      key: ValueKey('${user.id}-${user.role.apiValue}'),
      providers: [
        ChangeNotifierProvider(create: (_) => HomeNavigation(user.role)),
        ChangeNotifierProvider(
          create: (_) => DashboardViewModel(role: user.role, catalog: catalog, orders: orders, admin: admin),
        ),
        ChangeNotifierProvider(create: (_) => OrdersAgendaViewModel(orders)),
        ChangeNotifierProvider(create: (_) => SearchViewModel(catalog)),
        ChangeNotifierProvider(create: (_) => UsersViewModel(admin)),
        ChangeNotifierProvider(
          create: (_) => NotificationsViewModel(context.read<NotificationService>(), notifier: context.read<PushNotifications>()),
        ),
        ChangeNotifierProvider(create: (_) => ChatsViewModel(context.read<ChatService>(), enabled: user.role != UserRole.admin)),
        ChangeNotifierProvider(create: (_) => SalesViewModel(context.read<PaymentService>())),
        ChangeNotifierProvider(create: (_) => WalletViewModel(providers)),
        ChangeNotifierProvider(create: (_) => ProviderProfileViewModel(providers, session: session)),
      ],
      child: NotificationPopups(child: _HomeShell(role: user.role)),
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.role});

  final UserRole role;

  Widget _tabBody(AppTab tab) => switch (tab) {
    AppTab.home => switch (role) {
      UserRole.cliente => const ClientHomeTab(),
      UserRole.prestador => const ProviderHomeTab(),
      UserRole.admin => const AdminHomeTab(),
    },
    AppTab.search => const SearchTab(),
    AppTab.chats => const ChatsTab(),
    AppTab.agenda => const ClientAgendaTab(),
    AppTab.providerAgenda => const ProviderAgendaTab(),
    AppTab.wallet => const WalletTab(),
    AppTab.profile => const ProfessionalProfileTab(),
    AppTab.users => const UsersTab(),
    AppTab.orders => const OrdersFilterList(title: 'Pedidos', adminView: true),
    AppTab.sales => const SalesTab(role: UserRole.admin),
    AppTab.account => const AccountTab(),
  };

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<HomeNavigation>();
    final chatUnread = context.select<ChatsViewModel, int>((vm) => vm.unread);
    final c = context.bikoColors;
    // As telas com topo azul desenham por baixo da barra de status.
    final edgeToEdge = nav.current == AppTab.home || nav.current == AppTab.search;

    return TabBackHandler(
      child: Scaffold(
        body: SafeArea(
          top: !edgeToEdge,
          bottom: false,
          child: KeyedSubtree(key: ValueKey(nav.current), child: _tabBody(nav.current)),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: NavigationBar(
            selectedIndex: nav.index,
            onDestinationSelected: (i) => nav.goTo(nav.tabs[i]),
            destinations: [
              for (final t in nav.tabs)
                NavigationDestination(
                  icon: _badged(t, chatUnread, Icon(t.icon)),
                  selectedIcon: _badged(t, chatUnread, Icon(t.selectedIcon)),
                  label: t.label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badged(AppTab t, int unread, Widget icon) {
    if (t != AppTab.chats || unread == 0) return icon;
    return Badge(
      backgroundColor: const Color(0xFFFF9500),
      textColor: Colors.white,
      label: Text(unread > 9 ? '9+' : '$unread'),
      child: icon,
    );
  }
}

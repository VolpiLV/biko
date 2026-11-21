import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/user_model.dart';
import '../../../data/models/user_role.dart';
import '../../../data/remote/admin_service.dart';
import '../../../data/remote/catalog_service.dart';
import '../../../data/remote/notification_service.dart';
import '../../../data/remote/order_service.dart';
import '../../../data/remote/payment_service.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../account/views/account_tab.dart';
import '../../admin/viewmodels/users_view_model.dart';
import '../../admin/views/users_tab.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../notifications/viewmodels/notifications_view_model.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../orders/viewmodels/orders_view_model.dart';
import '../../orders/views/orders_tab.dart';
import '../../payments/viewmodels/sales_view_model.dart';
import '../../payments/views/sales_tab.dart';
import '../../search/viewmodels/search_view_model.dart';
import '../../search/views/search_tab.dart';
import '../../services/viewmodels/my_services_view_model.dart';
import '../../services/views/services_tab.dart';
import '../../settings/widgets/theme_mode_button.dart';
import '../viewmodels/dashboard_view_model.dart';
import '../viewmodels/home_navigation.dart';
import 'dashboard_tab.dart';

/// Área logada: abas conforme o perfil (cliente, prestador ou admin).
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
    final notifications = context.read<NotificationService>();
    final payments = context.read<PaymentService>();

    return MultiProvider(
      // Outro usuário (ou perfil alterado) = estado novo.
      key: ValueKey('${user.id}-${user.role.apiValue}'),
      providers: [
        ChangeNotifierProvider(create: (_) => HomeNavigation(user.role)),
        ChangeNotifierProvider(
          create: (_) => DashboardViewModel(role: user.role, catalog: catalog, orders: orders, admin: admin),
        ),
        ChangeNotifierProvider(create: (_) => OrdersViewModel(orders)),
        ChangeNotifierProvider(create: (_) => SearchViewModel(catalog)),
        ChangeNotifierProvider(create: (_) => MyServicesViewModel(catalog)),
        ChangeNotifierProvider(create: (_) => UsersViewModel(admin)),
        ChangeNotifierProvider(create: (_) => NotificationsViewModel(notifications)),
        ChangeNotifierProvider(create: (_) => SalesViewModel(payments)),
      ],
      child: _HomeShell(user: user),
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.user});

  final UserModel user;

  String get _subtitle => switch (user.role) {
        UserRole.cliente => 'O que você precisa hoje?',
        UserRole.prestador => 'Veja seus pedidos de hoje',
        UserRole.admin => 'Painel administrativo',
      };

  Widget _tabBody(AppTab tab) => switch (tab) {
        AppTab.home => const DashboardTab(),
        AppTab.search => const SearchTab(),
        AppTab.services => const ServicesTab(),
        AppTab.users => const UsersTab(),
        AppTab.orders => OrdersTab(role: user.role),
        AppTab.payments || AppTab.sales => SalesTab(role: user.role),
        AppTab.account => const AccountTab(),
      };

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<HomeNavigation>();
    final theme = Theme.of(context);
    // No Chrome em tela larga a navegação vai para a lateral.
    final wide = MediaQuery.sizeOf(context).width >= 840;

    final body = KeyedSubtree(key: ValueKey(nav.current), child: _tabBody(nav.current));

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Olá, ${user.firstName} 👋', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(_subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          const NotificationBell(),
          const ThemeModeButton(),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => nav.goTo(AppTab.account),
              child: UserAvatar(user: user, radius: 20),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: nav.index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (i) => nav.goTo(nav.tabs[i]),
                    destinations: [
                      for (final t in nav.tabs)
                        NavigationRailDestination(
                          icon: Icon(t.icon),
                          selectedIcon: Icon(t.selectedIcon),
                          label: Text(t.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: nav.index,
              onDestinationSelected: (i) => nav.goTo(nav.tabs[i]),
              destinations: [
                for (final t in nav.tabs)
                  NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
              ],
            ),
    );
  }
}

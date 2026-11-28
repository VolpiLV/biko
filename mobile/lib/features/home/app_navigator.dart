import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/user_role.dart';
import '../../features/auth/viewmodels/session_view_model.dart';
import '../chat/viewmodels/chat_view_models.dart';
import '../chat/views/chat_screen.dart';
import '../client/views/order_screen.dart';
import '../client/views/provider_public_screen.dart';
import '../notifications/viewmodels/notifications_view_model.dart';
import '../provider/views/request_screen.dart';
import 'viewmodels/home_navigation.dart';

/// Abre uma tela por cima da área logada. Leva junto o sino, o contador de conversas
/// e a navegação das abas, que vivem na Home.
Future<T?> pushScreen<T>(BuildContext context, Widget screen) {
  final notifications = context.read<NotificationsViewModel>();
  final chats = context.read<ChatsViewModel>();
  final nav = context.read<HomeNavigation>();
  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: notifications),
          ChangeNotifierProvider.value(value: chats),
          ChangeNotifierProvider.value(value: nav),
        ],
        child: screen,
      ),
    ),
  );
}

/// Troca a tela atual por outra (ex.: pagamento -> pedido confirmado, sem voltar ao pagamento).
Future<T?> replaceScreen<T>(BuildContext context, Widget screen) {
  final notifications = context.read<NotificationsViewModel>();
  final chats = context.read<ChatsViewModel>();
  final nav = context.read<HomeNavigation>();
  return Navigator.of(context).pushReplacement<T, Object?>(
    MaterialPageRoute(
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: notifications),
          ChangeNotifierProvider.value(value: chats),
          ChangeNotifierProvider.value(value: nav),
        ],
        child: screen,
      ),
    ),
  );
}

/// Fecha as telas empilhadas e vai para uma aba.
void goToTab(BuildContext context, AppTab tab) {
  final nav = context.read<HomeNavigation>();
  Navigator.of(context).popUntil((r) => r.isFirst);
  nav.goTo(tab);
}

/// Abre o pedido na tela certa: o prestador vê "Detalhes da Solicitação"; cliente e admin, o detalhe.
Future<void> openOrder(BuildContext context, int orderId) {
  final role = context.read<SessionViewModel>().user?.role;
  return pushScreen<void>(
    context,
    role == UserRole.prestador ? RequestScreen(orderId: orderId) : OrderScreen(orderId: orderId),
  );
}

Future<void> openChat(BuildContext context, int userId) => pushScreen<void>(context, ChatScreen(userId: userId));

Future<void> openProvider(BuildContext context, int providerId) =>
    pushScreen<void>(context, ProviderPublicScreen(providerId: providerId));

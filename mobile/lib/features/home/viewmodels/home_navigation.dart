import 'package:flutter/material.dart';

import '../../../core/viewmodel/base_view_model.dart';
import '../../../data/models/user_role.dart';

/// Abas da área logada (as mesmas do site, no visual do Figma).
enum AppTab {
  home('Início', Icons.home_outlined, Icons.home_rounded),
  search('Buscar', Icons.search, Icons.search),
  chats('Conversas', Icons.chat_bubble_outline, Icons.chat_bubble),
  agenda('Agenda', Icons.event_available_outlined, Icons.event_available),
  providerAgenda('Agenda', Icons.event_available_outlined, Icons.event_available),
  wallet('Ganhos', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
  profile('Perfil', Icons.person_outline, Icons.person),
  users('Usuários', Icons.group_outlined, Icons.group),
  orders('Pedidos', Icons.list_alt_outlined, Icons.list_alt),
  sales('Vendas', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
  account('Conta', Icons.person_outline, Icons.person);

  const AppTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Cada perfil vê só as abas que pode usar (o backend também bloqueia).
  static List<AppTab> forRole(UserRole role) => switch (role) {
        UserRole.cliente => const [home, search, chats, agenda],
        UserRole.prestador => const [home, providerAgenda, chats, wallet, profile],
        UserRole.admin => const [home, users, orders, sales, account],
      };
}

/// Aba atual. Outras telas usam [goTo] para atalhos (ex.: categoria -> busca).
/// Guarda as abas visitadas: o "voltar" do celular (botão ou gesto) volta para a aba anterior.
class HomeNavigation extends BaseViewModel {
  HomeNavigation(UserRole role) : tabs = AppTab.forRole(role);

  static const _maxHistory = 20;

  final List<AppTab> tabs;
  final List<AppTab> _history = [];
  AppTab _current = AppTab.home;

  AppTab get current => _current;
  int get index => tabs.indexOf(_current);

  /// Há para onde voltar (aba anterior ou o Início).
  bool get canGoBack => _history.isNotEmpty || _current != AppTab.home;

  void goTo(AppTab tab) {
    if (!tabs.contains(tab) || tab == _current) return;
    if (tab == AppTab.home) {
      // Chegou ao Início: dali o "voltar" pergunta se quer sair, não refaz o caminho.
      _history.clear();
    } else {
      // A aba sai do meio do histórico para não repetir (A -> B -> A -> B não vira 4 voltas).
      _history
        ..remove(tab)
        ..remove(_current)
        ..add(_current);
      if (_history.length > _maxHistory) _history.removeAt(0);
    }
    _current = tab;
    notify();
  }

  /// Volta para a aba anterior; sem histórico, para o Início. Retorna false se já está no Início.
  bool back() {
    if (_history.isNotEmpty) {
      _current = _history.removeLast();
    } else if (_current != AppTab.home) {
      _current = AppTab.home;
    } else {
      return false;
    }
    notify();
    return true;
  }
}

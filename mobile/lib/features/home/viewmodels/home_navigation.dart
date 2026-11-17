import 'package:flutter/material.dart';

import '../../../core/viewmodel/base_view_model.dart';
import '../../../data/models/user_role.dart';

/// Abas da área logada (as mesmas do sistema web).
enum AppTab {
  home('Início', Icons.home_outlined, Icons.home),
  search('Buscar', Icons.search_outlined, Icons.search),
  services('Serviços', Icons.handyman_outlined, Icons.handyman),
  users('Usuários', Icons.group_outlined, Icons.group),
  orders('Pedidos', Icons.event_note_outlined, Icons.event_note),
  account('Conta', Icons.person_outline, Icons.person);

  const AppTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Cada perfil vê só as abas que pode usar (o backend também bloqueia).
  static List<AppTab> forRole(UserRole role) => switch (role) {
        UserRole.cliente => const [home, search, orders, account],
        UserRole.prestador => const [home, services, orders, account],
        UserRole.admin => const [home, users, orders, account],
      };
}

/// Aba atual. Outras telas usam [goTo] para atalhos (ex.: categoria -> busca).
class HomeNavigation extends BaseViewModel {
  HomeNavigation(UserRole role) : tabs = AppTab.forRole(role);

  final List<AppTab> tabs;
  AppTab _current = AppTab.home;

  AppTab get current => _current;
  int get index => tabs.indexOf(_current);

  void goTo(AppTab tab) {
    if (!tabs.contains(tab) || tab == _current) return;
    _current = tab;
    notify();
  }
}

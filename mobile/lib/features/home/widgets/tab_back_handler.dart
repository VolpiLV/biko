import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../viewmodels/home_navigation.dart';

/// "Voltar" do Android (botão da barra de baixo ou gesto de arrastar da borda) na área das abas:
/// volta para a aba anterior; no Início, avisa e só fecha o app num segundo toque.
/// Telas abertas por cima (pedido, chat, perfil...) e folhas de baixo fecham antes, pelo Navigator.
class TabBackHandler extends StatefulWidget {
  const TabBackHandler({super.key, required this.child, this.onExit = SystemNavigator.pop});

  final Widget child;

  /// Fecha o app (troca nos testes).
  final Future<void> Function() onExit;

  static const exitWindow = Duration(seconds: 2);
  static const exitMessage = 'Toque em voltar de novo para sair';

  @override
  State<TabBackHandler> createState() => _TabBackHandlerState();
}

class _TabBackHandlerState extends State<TabBackHandler> {
  /// Ligado no 1º toque no Início; desliga sozinho depois de [TabBackHandler.exitWindow].
  Timer? _exitArmed;

  @override
  void dispose() {
    _exitArmed?.cancel();
    super.dispose();
  }

  void _onBack(bool didPop, Object? _) {
    if (didPop) return;
    if (context.read<HomeNavigation>().back()) {
      _exitArmed?.cancel();
      _exitArmed = null;
      return;
    }
    if (_exitArmed?.isActive ?? false) {
      widget.onExit();
      return;
    }
    _exitArmed = Timer(TabBackHandler.exitWindow, () {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(TabBackHandler.exitMessage), duration: TabBackHandler.exitWindow));
  }

  @override
  Widget build(BuildContext context) =>
      PopScope<Object?>(canPop: false, onPopInvokedWithResult: _onBack, child: widget.child);
}

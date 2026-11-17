import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/viewmodels/session_view_model.dart';
import 'features/settings/viewmodels/theme_view_model.dart';

class BikoApp extends StatefulWidget {
  const BikoApp({super.key});

  @override
  State<BikoApp> createState() => _BikoAppState();
}

class _BikoAppState extends State<BikoApp> {
  // Criado uma única vez: recriar o GoRouter a cada build perderia a pilha de telas.
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(context.read<SessionViewModel>());
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<ThemeViewModel, ThemeMode>((vm) => vm.mode);
    return MaterialApp.router(
      title: 'Biko',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
      // Calendário, botões padrão e textos do sistema em português.
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

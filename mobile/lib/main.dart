import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'data/local/preferences_store.dart';
import 'data/local/token_storage.dart';
import 'data/remote/auth_service.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/viewmodels/session_view_model.dart';
import 'features/settings/viewmodels/theme_view_model.dart';

/// Composição das dependências: cada camada recebe o que precisa pelo construtor.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = PreferencesStore(await SharedPreferences.getInstance());
  final tokenStorage = SecureTokenStorage();
  final api = ApiClient(tokenStorage: tokenStorage);
  final authRepository = AuthRepository(
    service: AuthService(api),
    tokens: tokenStorage,
  );
  final session = SessionViewModel(authRepository, api.onUnauthorized);
  unawaited(session.restore());

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<SessionViewModel>.value(value: session),
        ChangeNotifierProvider<ThemeViewModel>(
          create: (_) => ThemeViewModel(preferences),
        ),
      ],
      child: const BikoApp(),
    ),
  );
}

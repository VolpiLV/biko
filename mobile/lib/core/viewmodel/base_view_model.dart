import 'package:flutter/foundation.dart';

/// Base dos ViewModels: evita notifyListeners() depois do dispose
/// (ex.: uma requisição termina depois que o usuário saiu da tela).
abstract class BaseViewModel extends ChangeNotifier {
  bool _disposed = false;

  @protected
  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

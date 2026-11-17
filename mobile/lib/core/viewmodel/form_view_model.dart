import '../errors/app_exception.dart';
import 'base_view_model.dart';

/// Estado de envio de um formulário: carregando, mensagem de erro geral e
/// erros por campo devolvidos pela API (ex.: {'email': 'E-mail já cadastrado.'}).
class FormViewModel extends BaseViewModel {
  bool _loading = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  String? fieldError(String field) => _fieldErrors[field];

  /// O usuário mexeu no campo: o erro do servidor deixa de valer.
  void clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) return;
    _fieldErrors = Map.of(_fieldErrors)..remove(field);
    notify();
  }

  void clearErrors() {
    _errorMessage = null;
    _fieldErrors = const {};
    notify();
  }

  /// Executa [action]. Retorna o resultado, ou null se deu erro (o erro fica em
  /// [errorMessage]/[fieldError]). Quando todo erro é de campo, a mensagem
  /// geral genérica ("Dados inválidos.") não é repetida no topo.
  Future<T?> submit<T>(Future<T> Function() action) async {
    if (_loading) return null;
    _loading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notify();
    try {
      return await action();
    } on AppException catch (e) {
      _fieldErrors = e.fields;
      _errorMessage = e.fields.isNotEmpty && e.message == 'Dados inválidos.' ? null : e.message;
      return null;
    } finally {
      _loading = false;
      notify();
    }
  }
}

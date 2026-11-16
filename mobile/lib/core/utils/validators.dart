/// Validadores de formulário. Seguem as mesmas regras do backend (server.js),
/// para o usuário ver o erro antes de enviar.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final RegExp _letter = RegExp('[A-Za-z]');
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _nonDigit = RegExp(r'\D');

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe seu nome.';
    if (text.length < 3) return 'Informe o nome completo (mín. 3 caracteres).';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe o e-mail.';
    if (!_email.hasMatch(text)) return 'Informe um e-mail válido.';
    return null;
  }

  /// No login só exigimos que a senha tenha sido digitada.
  static String? loginPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Informe a senha.' : null;

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Crie uma senha.';
    if (value.length < 8) return 'A senha deve ter no mínimo 8 caracteres.';
    if (!_letter.hasMatch(value) || !_digit.hasMatch(value)) {
      return 'A senha deve conter letras e números.';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) =>
      (value) {
        if (value == null || value.isEmpty) return 'Confirme a senha.';
        if (value != original()) return 'As senhas não conferem.';
        return null;
      };

  /// Telefone é opcional; se informado, precisa ter DDD (10 ou 11 dígitos).
  static String? optionalPhone(String? value) {
    final digits = (value ?? '').replaceAll(_nonDigit, '');
    if (digits.isEmpty) return null;
    if (digits.length < 10 || digits.length > 11) {
      return 'Informe o telefone com DDD.';
    }
    return null;
  }
}

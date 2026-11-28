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

  /// Login aceita e-mail ou telefone (com DDD), como no site.
  static String? loginId(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe o e-mail ou telefone.';
    if (!_email.hasMatch(text) && text.replaceAll(_nonDigit, '').length < 10) {
      return 'Informe um e-mail ou telefone válido.';
    }
    return null;
  }

  /// CPF com os dois dígitos verificadores (o mesmo cálculo da Receita e do server.js).
  static bool cpfValid(String value) {
    final cpf = value.replaceAll(_nonDigit, '');
    if (cpf.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;
    int dig(int n) {
      var s = 0;
      for (var i = 0; i < n; i++) {
        s += int.parse(cpf[i]) * (n + 1 - i);
      }
      final r = (s * 10) % 11;
      return r == 10 ? 0 : r;
    }

    return dig(9) == int.parse(cpf[9]) && dig(10) == int.parse(cpf[10]);
  }

  static String? cpf(String? value) => cpfValid(value ?? '') ? null : 'CPF inválido. Confira os números.';

  /// Idade a partir de "DD/MM/AAAA". null se a data não existe ou está no futuro.
  static int? ageOf(String? value, {DateTime? today}) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value ?? '');
    if (m == null) return null;
    final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), y = int.parse(m.group(3)!);
    final date = DateTime(y, mo, d);
    final now = today ?? DateTime.now();
    if (date.month != mo || date.day != d || date.isAfter(now) || y < 1900) return null;
    var age = now.year - y;
    if (now.month < mo || (now.month == mo && now.day < d)) age--;
    return age;
  }

  static String? birthDate(String? value) {
    final age = ageOf(value);
    if (age == null) return 'Informe a data no formato DD/MM/AAAA.';
    if (age < 18) return 'Apenas maiores de 18 anos podem prestar serviços no Biko.';
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

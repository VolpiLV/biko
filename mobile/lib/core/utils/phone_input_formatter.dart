import 'package:flutter/services.dart';

/// Máscara de telefone brasileiro: (47) 9999-0000 ou (47) 99999-0000.
class PhoneInputFormatter extends TextInputFormatter {
  static final RegExp _nonDigit = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = format(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  static String format(String input) {
    var digits = input.replaceAll(_nonDigit, '');
    if (digits.length > 11) digits = digits.substring(0, 11);
    if (digits.isEmpty) return '';
    // Só fecha o parêntese quando já existe o 3º dígito; senão o backspace "trava" no ") ".
    if (digits.length <= 2) return '($digits';
    final ddd = digits.substring(0, 2);
    final rest = digits.substring(2);
    if (rest.length <= 4) return '($ddd) $rest';
    final split = digits.length == 11 ? 5 : 4;
    if (rest.length <= split) return '($ddd) $rest';
    return '($ddd) ${rest.substring(0, split)}-${rest.substring(split)}';
  }
}

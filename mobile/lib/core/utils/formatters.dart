/// Formatação de valores para exibição (mesmo formato do sistema web).
abstract final class Fmt {
  /// 1234.5 -> "R$ 1.234,50"
  static String brl(num value) {
    final negative = value < 0;
    final cents = (value.abs() * 100).round();
    final reais = (cents ~/ 100).toString();
    final buffer = StringBuffer();
    for (var i = 0; i < reais.length; i++) {
      if (i > 0 && (reais.length - i) % 3 == 0) buffer.write('.');
      buffer.write(reais[i]);
    }
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}R\$ $buffer,$centavos';
  }

  /// "2026-11-20" -> "20/11/2026"
  static String dateBR(String ymd) => ymd.split('-').reversed.join('/');

  /// 90 -> "1 h 30 min"
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    if (minutes % 60 == 0) return '${minutes ~/ 60} h';
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }

  static String two(int n) => n.toString().padLeft(2, '0');

  /// Data local -> "AAAA-MM-DD" (formato que a API espera).
  static String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

  /// Data e hora local curtas: "20/11/2026 14:30".
  static String dateTime(DateTime d) {
    final l = d.toLocal();
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  /// "HH:MM" -> minutos desde a meia-noite.
  static int toMinutes(String hhmm) =>
      int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));

  /// Minutos desde a meia-noite -> "HH:MM".
  static String hhmm(int minutes) => '${two(minutes ~/ 60)}:${two(minutes % 60)}';

  /// Aceita "120", "120,5" ou "120.50". Retorna null se não for número.
  static double? parseMoney(String text) =>
      double.tryParse(text.trim().replaceAll('R\$', '').replaceAll(' ', '').replaceAll(',', '.'));
}

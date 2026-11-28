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

  static const List<String> weekdays = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
  static const List<String> months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  /// "SEG", "TER"... (DateTime.weekday vai de 1 = segunda a 7 = domingo).
  static String weekday(DateTime d) => weekdays[d.weekday - 1];

  static DateTime parseYmd(String ymd) {
    final p = ymd.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  /// "Hoje", "Amanhã", "Ontem" ou "Qua, 26/11".
  static String dayLabel(String ymd, {DateTime? now}) {
    final d = parseYmd(ymd);
    final n = now ?? DateTime.now();
    // Em UTC para o horário de verão não atrapalhar a conta de dias.
    final diff = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Amanhã';
    if (diff == -1) return 'Ontem';
    final w = weekday(d);
    return '${w[0]}${w.substring(1).toLowerCase()}, ${two(d.day)}/${two(d.month)}';
  }

  /// "Hoje, 23/11" ou "Qui, 26/11".
  static String fullDay(String ymd) {
    final l = dayLabel(ymd);
    return l.contains(',') ? l : '$l, ${dateBR(ymd).substring(0, 5)}';
  }

  /// Dia de um instante (mensagens, carteira): "Hoje", "Ontem"...
  static String dayOf(DateTime t) => dayLabel(ymd(t));

  /// "14:30"
  static String time(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

  /// 4.8 -> "4,8"
  static String rating(num r) => r.toStringAsFixed(1).replaceAll('.', ',');

  /// Máscara 000.000.000-00
  static String cpf(String input) {
    final d = input.replaceAll(RegExp(r'\D'), '');
    final s = d.length > 11 ? d.substring(0, 11) : d;
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i == 3 || i == 6) b.write('.');
      if (i == 9) b.write('-');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// Máscara DD/MM/AAAA
  static String birth(String input) {
    final d = input.replaceAll(RegExp(r'\D'), '');
    final s = d.length > 8 ? d.substring(0, 8) : d;
    if (s.length > 4) return '${s.substring(0, 2)}/${s.substring(2, 4)}/${s.substring(4)}';
    if (s.length > 2) return '${s.substring(0, 2)}/${s.substring(2)}';
    return s;
  }

  /// Aceita "120", "120,5" ou "120.50". Retorna null se não for número.
  static double? parseMoney(String text) =>
      double.tryParse(text.trim().replaceAll('R\$', '').replaceAll(' ', '').replaceAll(',', '.'));
}

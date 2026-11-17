// Leitura tipada de JSON. Qualquer campo ausente ou com tipo errado vira
// FormatException, que o ApiClient converte em mensagem amigável.

Map<String, dynamic> readMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw FormatException('Campo "$key" ausente ou inválido.');
}

int readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is double && value == value.roundToDouble()) return value.toInt();
  throw FormatException('Campo "$key" deveria ser um número inteiro.');
}

/// Números que podem vir inteiros ou decimais (preços, valores em reais).
double readNum(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('Campo "$key" deveria ser um número.');
}

double? readNumOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('Campo "$key" deveria ser um número.');
}

/// Lista de objetos JSON convertidos com [parse].
List<T> readList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is! List) throw FormatException('Campo "$key" deveria ser uma lista.');
  return [
    for (final item in value)
      if (item is Map<String, dynamic>)
        parse(item)
      else
        throw FormatException('Item inválido em "$key".'),
  ];
}

String readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Campo "$key" deveria ser um texto.');
}

String? readStringOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Campo "$key" deveria ser um texto.');
}

/// Aceita bool (API) ou 0/1 (SQLite).
bool readBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  if (value is int) return value != 0;
  throw FormatException('Campo "$key" deveria ser verdadeiro/falso.');
}

/// O backend grava datas do SQLite como "AAAA-MM-DD HH:MM:SS" em UTC (sem fuso).
DateTime? readServerDateOrNull(Map<String, dynamic> json, String key) {
  final value = readStringOrNull(json, key);
  if (value == null || value.isEmpty) return null;
  var iso = value.replaceFirst(' ', 'T');
  final hasZone = iso.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(iso);
  if (!hasZone) iso = '${iso}Z';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) throw FormatException('Data inválida em "$key".');
  return parsed;
}

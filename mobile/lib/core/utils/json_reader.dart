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

import '../../core/utils/json_reader.dart';

/// Página de uma lista paginada por limit/offset.
class Paged<T> {
  const Paged({required this.items, required this.total, required this.hasMore});

  final List<T> items;
  final int total;
  final bool hasMore;

  /// Formato de /api/users e /api/orders: `{ key: [...], total, has_more }`.
  factory Paged.fromJson(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) =>
      Paged(
        items: readList(json, key, parse),
        total: readInt(json, 'total'),
        hasMore: readBool(json, 'has_more'),
      );

  /// Formato de /api/search: { results, total, limit, offset } (sem has_more).
  factory Paged.fromSearch(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final items = readList(json, 'results', parse);
    final total = readInt(json, 'total');
    final offset = readInt(json, 'offset');
    return Paged(items: items, total: total, hasMore: offset + items.length < total);
  }
}

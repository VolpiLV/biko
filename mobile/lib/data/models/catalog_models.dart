import 'package:flutter/material.dart';

import '../../core/utils/json_reader.dart';

/// Categoria de serviço (`categoryList()` no server.js).
class CategoryModel {
  const CategoryModel({required this.name, required this.description, required this.total});

  final String name;
  final String description;

  /// Quantos serviços ativos existem na categoria.
  final int total;

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        name: readString(json, 'nome'),
        description: readString(json, 'desc'),
        total: readInt(json, 'total'),
      );

  /// Ícone de cada categoria (mesmas do backend).
  static IconData iconFor(String category) => switch (category) {
        'Telhado & Reparador' => Icons.roofing_outlined,
        'Encanador' => Icons.plumbing_outlined,
        'Eletricista' => Icons.electrical_services_outlined,
        'Pintor' => Icons.format_paint_outlined,
        'Limpeza' => Icons.cleaning_services_outlined,
        'Jardinagem' => Icons.yard_outlined,
        _ => Icons.handyman_outlined,
      };
}

/// Serviço oferecido por um prestador (`serviceView` no server.js).
class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    required this.durationMin,
    required this.active,
    this.providerPhotoUrl,
  });

  final int id;
  final int providerId;
  final String providerName;
  final String? providerPhotoUrl;
  final String title;
  final String category;
  final String description;
  final double price;
  final int durationMin;
  final bool active;

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
        id: readInt(json, 'id'),
        providerId: readInt(json, 'provider_id'),
        providerName: readString(json, 'provider_name'),
        providerPhotoUrl: readStringOrNull(json, 'provider_photo_url'),
        title: readString(json, 'title'),
        category: readString(json, 'category'),
        description: readStringOrNull(json, 'description') ?? '',
        price: readNum(json, 'price'),
        durationMin: readInt(json, 'duration_min'),
        active: readBool(json, 'active'),
      );
}

/// Dados enviados ao criar/editar um serviço.
class ServiceInput {
  const ServiceInput({
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    required this.durationMin,
    this.active,
  });

  final String title;
  final String category;
  final String description;
  final double price;
  final int durationMin;

  /// Só é enviado na edição.
  final bool? active;

  Map<String, dynamic> toJson() => {
        'title': title.trim(),
        'category': category,
        'description': description.trim(),
        'price': price,
        'duration_min': durationMin,
        if (active != null) 'active': active,
      };
}

/// Ordenações aceitas por /api/search.
enum SearchSort {
  relevance('', 'Mais relevantes'),
  priceAsc('preco_asc', 'Menor preço'),
  priceDesc('preco_desc', 'Maior preço'),
  name('nome', 'Nome (A–Z)');

  const SearchSort(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Filtros da busca do cliente.
class SearchFilters {
  const SearchFilters({
    this.query = '',
    this.category = '',
    this.maxPrice,
    this.sort = SearchSort.relevance,
  });

  final String query;
  final String category;
  final double? maxPrice;
  final SearchSort sort;

  bool get isEmpty =>
      query.isEmpty && category.isEmpty && maxPrice == null && sort == SearchSort.relevance;

  SearchFilters copyWith({
    String? query,
    String? category,
    double? Function()? maxPrice,
    SearchSort? sort,
  }) =>
      SearchFilters(
        query: query ?? this.query,
        category: category ?? this.category,
        maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
        sort: sort ?? this.sort,
      );

  Map<String, Object?> toQuery() => {
        if (query.isNotEmpty) 'q': query,
        if (category.isNotEmpty) 'category': category,
        if (maxPrice != null) 'max_price': maxPrice,
        if (sort.apiValue.isNotEmpty) 'sort': sort.apiValue,
      };
}

/// Horário ocupado na agenda do prestador ("HH:MM").
class BusySlot {
  const BusySlot({required this.start, required this.end});

  final String start;
  final String end;

  factory BusySlot.fromJson(Map<String, dynamic> json) =>
      BusySlot(start: readString(json, 'start'), end: readString(json, 'end'));
}

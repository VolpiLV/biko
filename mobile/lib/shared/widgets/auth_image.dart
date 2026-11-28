import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';

/// Imagem de uma rota da API que exige o token (foto de perfil, portfólio).
/// É baixada pelo ApiClient (com Authorization) e mostrada com Image.memory.
class AuthImage extends StatefulWidget {
  const AuthImage({super.key, required this.url, required this.fallback, this.fit = BoxFit.cover});

  final String url;
  final Widget fallback;
  final BoxFit fit;

  /// Esquece a imagem guardada (ex.: depois de remover uma foto do portfólio).
  static void evict(String url) => _AuthImageState._cache.remove(url);

  @override
  State<AuthImage> createState() => _AuthImageState();
}

class _AuthImageState extends State<AuthImage> {
  // As URLs de foto mudam (?v=N) quando a imagem é trocada, então dá para guardar por URL.
  static final Map<String, Future<Uint8List>> _cache = {};

  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant AuthImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _future = _load();
  }

  Future<Uint8List> _load() {
    final api = context.read<ApiClient>();
    return _cache.putIfAbsent(widget.url, () {
      final future = api.getBytes(widget.url);
      // Se falhar (sem rede), não guarda o erro: tenta de novo na próxima vez.
      future.catchError((Object _) {
        _cache.remove(widget.url);
        return Uint8List(0);
      });
      return future;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) return widget.fallback;
          return Image.memory(bytes, fit: widget.fit, gaplessPlayback: true, errorBuilder: (_, _, _) => widget.fallback);
        },
      );
}

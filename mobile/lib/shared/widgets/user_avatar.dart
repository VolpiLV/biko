import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../data/models/user_model.dart';

/// Avatar: foto de perfil (se houver) ou as iniciais do nome.
class UserAvatar extends StatelessWidget {
  UserAvatar({super.key, required UserModel user, this.radius = 28})
      : name = user.name,
        photoUrl = user.photoUrl;

  /// Para pessoas que não são um [UserModel] completo (prestador na busca, cliente no pedido).
  const UserAvatar.named({super.key, required this.name, this.photoUrl, this.radius = 28});

  final String name;
  final String? photoUrl;
  final double radius;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final text = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return text.isEmpty ? '?' : text;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(
        _initials,
        style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w700),
      ),
    );
    final url = photoUrl;
    return Semantics(
      label: url == null ? 'Avatar de $name' : 'Foto de $name',
      image: true,
      excludeSemantics: true,
      child: url == null ? initials : _AuthPhoto(url: url, radius: radius, fallback: initials),
    );
  }
}

/// A rota /api/photo/:id exige o token, então a foto é baixada pelo ApiClient
/// (com o cabeçalho Authorization) e mostrada com Image.memory.
class _AuthPhoto extends StatefulWidget {
  const _AuthPhoto({required this.url, required this.radius, required this.fallback});

  final String url;
  final double radius;
  final Widget fallback;

  @override
  State<_AuthPhoto> createState() => _AuthPhotoState();
}

class _AuthPhotoState extends State<_AuthPhoto> {
  // A URL muda (?v=N) quando a foto é trocada, então dá para guardar por URL.
  static final Map<String, Future<Uint8List>> _cache = {};

  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _AuthPhoto oldWidget) {
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
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) return widget.fallback;
        return CircleAvatar(
          radius: widget.radius,
          backgroundImage: MemoryImage(bytes),
          onBackgroundImageError: (_, _) {},
        );
      },
    );
  }
}

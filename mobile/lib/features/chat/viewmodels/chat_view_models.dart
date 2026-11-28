import 'dart:async';

import '../../../core/errors/app_exception.dart';
import '../../../core/viewmodel/base_view_model.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/remote/chat_service.dart';

/// Aba "Conversas" e o número de não lidas na barra de baixo (atualiza sozinho).
class ChatsViewModel extends BaseViewModel {
  ChatsViewModel(this._service, {this.enabled = true, Duration pollEvery = const Duration(seconds: 20)}) {
    if (!enabled) return;
    unawaited(load(quiet: true));
    if (pollEvery > Duration.zero) _timer = Timer.periodic(pollEvery, (_) => load(quiet: true));
  }

  final ChatService _service;

  /// O admin não participa das conversas.
  final bool enabled;
  Timer? _timer;

  List<Conversation> _items = const [];
  int _unread = 0;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<Conversation> get items => _items;
  int get unread => _unread;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  /// [quiet]: atualização de fundo (não mostra carregando nem erro).
  Future<void> load({bool quiet = false}) async {
    if (!enabled) return;
    if (!quiet) {
      _loading = true;
      _error = null;
      notify();
    }
    try {
      final r = await _service.list();
      _items = r.items;
      _unread = r.unread;
      _loaded = true;
      _error = null;
    } on AppException catch (e) {
      if (!quiet) _error = e.message;
    }
    _loading = false;
    notify();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Uma conversa aberta. Busca mensagens novas a cada 4 s enquanto a tela está aberta.
class ChatThreadViewModel extends BaseViewModel {
  ChatThreadViewModel(this._service, this.userId, {Duration pollEvery = const Duration(seconds: 4)}) {
    unawaited(load());
    if (pollEvery > Duration.zero) _timer = Timer.periodic(pollEvery, (_) => _refresh());
  }

  final ChatService _service;

  /// A outra pessoa da conversa.
  final int userId;
  Timer? _timer;

  ChatThread? _thread;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  ChatThread? get thread => _thread;
  bool get loading => _loading;
  bool get sending => _sending;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notify();
    try {
      _thread = await _service.thread(userId);
    } on AppException catch (e) {
      _error = e.message;
    }
    _loading = false;
    notify();
  }

  Future<void> _refresh() async {
    if (_thread == null || _sending) return;
    try {
      final t = await _service.thread(userId);
      if (t.messages.length != _thread!.messages.length) {
        _thread = t;
        notify();
      }
    } on AppException {
      // tenta de novo na próxima rodada
    }
  }

  /// Retorna null se enviou, ou a mensagem de erro.
  Future<String?> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _sending) return null;
    _sending = true;
    notify();
    try {
      await _service.send(userId, t);
      _thread = await _service.thread(userId);
      return null;
    } on AppException catch (e) {
      return e.message;
    } finally {
      _sending = false;
      notify();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

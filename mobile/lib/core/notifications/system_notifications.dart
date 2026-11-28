import 'dart:async';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/models/notification_model.dart';
import '../config/env.dart';

/// Mostra uma notificação do Biko como pop-up do celular (barra de notificações).
/// É uma interface para os testes poderem trocar por uma versão de mentira.
abstract interface class SystemNotifier {
  Future<void> show(AppNotification n);
}

/// Toque num pop-up: qual notificação foi e qual pedido abrir (cada um pode faltar).
class NotificationTap {
  const NotificationTap({this.notificationId, this.orderId});

  final int? notificationId;
  final int? orderId;

  /// Formato do payload dos pop-ups locais: "<id da notificação>:<id do pedido>".
  static String payloadOf(int notificationId, int? orderId) => '$notificationId:${orderId ?? ''}';

  static NotificationTap fromPayload(String? payload) {
    final parts = (payload ?? '').split(':');
    return NotificationTap(notificationId: int.tryParse(parts.first), orderId: parts.length > 1 ? int.tryParse(parts[1]) : null);
  }

  /// Dados do push do Firebase (montados pelo microsserviço em notificacoes/push.js).
  static NotificationTap fromData(Map<String, dynamic> data) => NotificationTap(
    notificationId: int.tryParse(data['notificacao_id']?.toString() ?? ''),
    orderId: int.tryParse(data['pedido_id']?.toString() ?? ''),
  );
}

/// Pop-ups de notificação no Android, em duas camadas:
///
/// 1. Com o app aberto (ou recém-minimizado): o sino já consulta o servidor a cada 20 s; o que
///    chegar de novo vira pop-up aqui ([show]). Não precisa de configuração nenhuma.
/// 2. Com o app fechado: push do Firebase Cloud Messaging, enviado pelo microsserviço de
///    notificações. Só liga quando o app é gerado com as chaves do Firebase ([Env.hasFirebase]).
///
/// Os dois usam a mesma "tag" (notif-<id>): se a mesma notificação chegar pelos dois caminhos,
/// o Android troca uma pela outra em vez de mostrar duas.
class PushNotifications implements SystemNotifier {
  PushNotifications();

  static const channelId = 'biko_pedidos';
  static const _channelName = 'Pedidos';
  static const _channelDescription = 'Novos pedidos, confirmações, atrasos e pagamentos';
  static const _icon = 'ic_stat_biko';
  static const _blue = Color(0xFF0A84FF);

  final _local = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<NotificationTap>.broadcast();
  final _received = StreamController<void>.broadcast();

  bool _ready = false;
  bool _fcm = false;
  NotificationTap? _pendingTap;

  /// Toques em pop-ups com o app aberto ou em segundo plano.
  Stream<NotificationTap> get taps => _taps.stream;

  /// Push chegou com o app aberto (para atualizar o número do sino na hora).
  Stream<void> get received => _received.stream;

  /// Push com o app fechado está ligado (app gerado com as chaves do Firebase).
  bool get pushEnabled => _fcm;

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Chamado uma vez no main(), antes do runApp. Nunca lança erro: sem notificações o app segue.
  Future<void> init() async {
    if (!_supported) return;
    try {
      await _local.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings(_icon)),
        onDidReceiveNotificationResponse: (r) => _tap(NotificationTap.fromPayload(r.payload)),
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(channelId, _channelName, description: _channelDescription, importance: Importance.high),
      );
      // O app foi aberto por um toque no pop-up (estava fechado).
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch != null && launch.didNotificationLaunchApp) {
        _pendingTap = NotificationTap.fromPayload(launch.notificationResponse?.payload);
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notificações locais indisponíveis: $e');
    }
    if (Env.hasFirebase) await _initFirebase();
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: Env.firebaseApiKey,
          appId: Env.firebaseAppId,
          messagingSenderId: Env.firebaseSenderId,
          projectId: Env.firebaseProjectId,
        ),
      );
      // Com o app aberto o Android não mostra o push sozinho: mostramos nós (mesma tag).
      FirebaseMessaging.onMessage.listen((m) {
        _received.add(null);
        final n = m.notification;
        final tap = NotificationTap.fromData(m.data);
        final id = tap.notificationId;
        if (n == null || id == null) return;
        unawaited(_showRaw(id, n.title ?? 'Biko', n.body ?? '', tap.orderId));
      });
      // Toque no push com o app em segundo plano / fechado.
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _tap(NotificationTap.fromData(m.data)));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pendingTap = NotificationTap.fromData(initial.data);
      _fcm = true;
    } catch (e) {
      debugPrint('Firebase Cloud Messaging indisponível: $e');
    }
  }

  /// Android 13+: pergunta se pode mostrar notificações (uma vez; depois o Android lembra).
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Token deste aparelho para o servidor mandar push (null sem Firebase).
  Future<String?> deviceToken() async {
    if (!_fcm) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _fcm ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();

  /// O toque que abriu o app (ou que chegou antes do login), uma vez só.
  NotificationTap? takePendingTap() {
    final t = _pendingTap;
    _pendingTap = null;
    return t;
  }

  @override
  Future<void> show(AppNotification n) => _showRaw(n.id, n.title, n.message, n.orderId);

  Future<void> _showRaw(int id, String title, String body, int? orderId) async {
    if (!_ready) return;
    try {
      await _local.show(
        id: 0,
        title: title,
        body: body,
        payload: NotificationTap.payloadOf(id, orderId),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: _icon,
            color: _blue,
            tag: 'notif-$id',
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Falha ao mostrar notificação: $e');
    }
  }

  void _tap(NotificationTap tap) {
    if (_taps.hasListener) {
      _taps.add(tap);
    } else {
      _pendingTap = tap; // ainda no login/splash: a Home abre quando aparecer
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_snackbar.dart';

/// "Ver Rota": abre o endereço no Google Maps (app ou navegador).
/// Se não houver nada para abrir, copia o endereço.
Future<void> openRoute(BuildContext context, String address) async {
  final uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': address});
  if (await _launch(uri)) return;
  await Clipboard.setData(ClipboardData(text: address));
  if (context.mounted) showAppSnackBar(context, 'Não deu para abrir o mapa. Endereço copiado.');
}

/// Ligar: abre o discador com o número (a pessoa confirma a ligação).
Future<void> callPhone(BuildContext context, String phone) async {
  final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (await _launch(Uri(scheme: 'tel', path: digits))) return;
  if (context.mounted) showAppSnackBar(context, 'Telefone: $phone');
}

Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  }
}

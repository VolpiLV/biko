import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/biko_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/user_role.dart';
import '../../../data/remote/chat_service.dart';
import '../../../shared/utils/launchers.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/biko_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_view_model.dart';
import '../../home/app_navigator.dart';
import '../viewmodels/chat_view_models.dart';

/// Conversa com uma pessoa (cliente ⇄ prestador). Atualiza sozinha a cada 4 s.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => ChatThreadViewModel(context.read<ChatService>(), userId),
        child: const _ChatView(),
      );
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = -1;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final vm = context.read<ChatThreadViewModel>();
    final text = _text.text;
    if (text.trim().isEmpty) return;
    _text.clear();
    final error = await vm.send(text);
    if (!mounted) return;
    if (error != null) {
      _text.text = text;
      showAppSnackBar(context, error, error: true);
    }
  }

  void _soon() => showAppSnackBar(context, 'Envio de fotos e arquivos ainda não está disponível nesta versão.');

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatThreadViewModel>();
    final c = context.bikoColors;
    final t = vm.thread;
    if (t == null) {
      return Scaffold(
        appBar: bikoAppBar(context, 'Conversa'),
        body: vm.loading ? const LoadingView() : ErrorView(message: vm.error ?? 'Não foi possível abrir a conversa.', onRetry: vm.load),
      );
    }
    if (t.messages.length != _lastCount) {
      _lastCount = t.messages.length;
      _scrollToEnd();
    }
    final o = t.other;
    final role = context.read<SessionViewModel>().user?.role;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.card,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Center(
            child: Material(
              color: c.neutralSoft,
              shape: const CircleBorder(),
              child: const BackButton(),
            ),
          ),
        ),
        centerTitle: false,
        titleSpacing: 4,
        title: Row(
          children: [
            BikoAvatar(name: o.name, photoUrl: o.photoUrl, size: 42, onlineDot: o.isProvider && o.online),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: c.ink)),
                  Text(
                    o.isProvider ? '${o.online ? 'Online' : 'Offline'}${o.specialty != null ? ' • ${o.specialty}' : ''}' : 'Cliente',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: o.isProvider && o.online ? c.green : c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (o.phone case final phone?)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: RoundIconButton(icon: Icons.phone_outlined, tooltip: 'Ligar ($phone)', onPressed: () => callPhone(context, phone)),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: RoundIconButton(
              icon: Icons.event_available_outlined,
              orange: true,
              tooltip: 'Agenda',
              onPressed: () {
                if (t.nextOrder case final n?) {
                  openOrder(context, n.id);
                } else if (role == UserRole.cliente) {
                  openProvider(context, o.id);
                } else {
                  showAppSnackBar(context, 'Nenhum pedido ativo com este cliente.');
                }
              },
            ),
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Divider(color: c.line)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: t.messages.isEmpty
                  ? Center(
                      child: EmptyText('Comece a conversa com ${o.name.split(' ').first}.\nConte o que precisa e combine os detalhes.'),
                    )
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      children: _bubbles(context, t),
                    ),
            ),
            if (t.nextOrder case final n?) _NextOrderBar(n),
            _Composer(controller: _text, sending: vm.sending, onSend: _send, onSoon: _soon),
          ],
        ),
      ),
    );
  }

  List<Widget> _bubbles(BuildContext context, ChatThread t) {
    final out = <Widget>[];
    String? lastDay;
    for (final m in t.messages) {
      final day = Fmt.dayOf(m.createdAt);
      if (day != lastDay) {
        out.add(_DaySeparator(day));
        lastDay = day;
      }
      out.add(_Bubble(message: m, other: t.other));
    }
    return out;
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator(this.day);

  final String day;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: c.neutralSoft, borderRadius: BorderRadius.circular(10)),
        child: Text(day, style: TextStyle(fontSize: 12, color: c.muted, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.other});

  final ChatMessage message;
  final ChatPerson other;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final mine = message.mine;
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: mine ? c.blue : c.card,
        border: Border.all(color: mine ? c.blue : c.line),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 6),
          bottomRight: Radius.circular(mine ? 6 : 18),
        ),
      ),
      child: Text(message.text, style: TextStyle(color: mine ? Colors.white : c.text, fontSize: 14, height: 1.45)),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[BikoAvatar(name: other.name, photoUrl: other.photoUrl, size: 28), const SizedBox(width: 8)],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
                  child: bubble,
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: mine ? 0 : 40, right: mine ? 4 : 0, top: 2),
            child: Text(Fmt.time(message.createdAt), style: TextStyle(fontSize: 11, color: c.muted2)),
          ),
        ],
      ),
    );
  }
}

class _NextOrderBar extends StatelessWidget {
  const _NextOrderBar(this.order);

  final ChatNextOrder order;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Material(
      color: c.card,
      child: InkWell(
        onTap: () => openOrder(context, order.id),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
          child: Row(
            children: [
              const Text('📅 '),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: order.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: ' · ${Fmt.dayLabel(order.date)} às ${order.time}'),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              const SizedBox(width: 6),
              Tag(order.status.label, tone: order.status == OrderStatus.confirmado ? TagTone.green : TagTone.orange),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend, required this.onSoon});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onSoon;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
      decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.line))),
      child: Row(
        children: [
          IconButton(onPressed: onSoon, tooltip: 'Anexar', icon: Icon(Icons.attach_file, color: c.muted)),
          IconButton(onPressed: onSoon, tooltip: 'Foto', icon: Icon(Icons.image_outlined, color: c.muted)),
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 1000,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Digite uma mensagem...',
                counterText: '',
                fillColor: c.neutralSoft,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: c.blue)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox.square(
            dimension: 44,
            child: IconButton.filled(
              onPressed: sending ? null : onSend,
              tooltip: 'Enviar',
              style: IconButton.styleFrom(backgroundColor: c.blue, foregroundColor: Colors.white),
              icon: sending
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

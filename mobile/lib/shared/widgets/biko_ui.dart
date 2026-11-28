import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/biko_colors.dart';
import '../../core/utils/formatters.dart';
import 'auth_image.dart';

// Peças visuais do protótipo do Figma (mesmas classes do public/style.css):
// cartão, botões, selos, avatar, avisos, faixa de dias etc.

/// Cartão branco arredondado com borda fina (`.card`).
class BikoCard extends StatelessWidget {
  const BikoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 14),
    this.highlight = false,
    this.accent,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;

  /// Borda azul grossa (resultado "MAIS BEM AVALIADO").
  final bool highlight;

  /// Faixa colorida à esquerda (cartões da agenda).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final radius = BorderRadius.circular(AppRadius.lg);
    Widget body = Padding(padding: padding, child: child);
    if (accent case final a?) {
      body = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Container(width: 4, color: a), Expanded(child: body)],
        ),
      );
    }
    return Padding(
      padding: margin,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: highlight ? c.blue : c.line, width: highlight ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

enum BikoButtonStyle { primary, green, orange, light, outline, danger, white }

/// Botão do Figma. É sempre um [FilledButton] (com ícone opcional depois do texto ou antes).
class BikoButton extends StatelessWidget {
  const BikoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = BikoButtonStyle.primary,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.small = false,
    this.expand = true,
    this.foreground,
  });

  final String label;
  final VoidCallback? onPressed;
  final BikoButtonStyle style;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool small;
  final bool expand;

  /// Cor do texto (ex.: "Cancelar pedido" vermelho num botão outline).
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final (bg, fg, side) = switch (style) {
      BikoButtonStyle.primary => (c.blue, Colors.white, BorderSide.none),
      BikoButtonStyle.green => (c.greenPay, Colors.white, BorderSide.none),
      BikoButtonStyle.orange => (c.orange, Colors.white, BorderSide.none),
      BikoButtonStyle.light => (c.neutralSoft, c.text, BorderSide.none),
      BikoButtonStyle.outline => (c.card, c.text, BorderSide(color: c.line, width: 1.5)),
      BikoButtonStyle.danger => (c.danger, Colors.white, BorderSide.none),
      BikoButtonStyle.white => (Colors.white, const Color(0xFFC46A00), BorderSide.none),
    };
    final color = foreground ?? fg;
    final iconSize = small ? 17.0 : 19.0;
    final content = loading
        ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: color))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: iconSize, color: color), const SizedBox(width: 8)],
              Flexible(child: Text(label, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2)),
              if (trailingIcon != null) ...[const SizedBox(width: 8), Icon(trailingIcon, size: iconSize, color: color)],
            ],
          );
    final button = FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: color,
        // Cor opaca (misturada com branco): sobre fundos coloridos não fica "suja".
        disabledBackgroundColor: Color.alphaBlend(bg.withValues(alpha: 0.5), Colors.white),
        disabledForegroundColor: color.withValues(alpha: 0.85),
        side: side,
        elevation: 0,
        minimumSize: Size(small ? 40 : 64, small ? 42 : AppSizes.buttonHeight),
        padding: EdgeInsets.symmetric(horizontal: small ? 14 : 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(small ? 12 : AppRadius.md)),
        textStyle: TextStyle(fontFamily: 'Poppins', fontSize: small ? 13.5 : 15, fontWeight: FontWeight.w600),
      ),
      child: Semantics(label: loading ? '$label: carregando' : null, child: content),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Dois botões lado a lado (`.btn-row`).
class ButtonPair extends StatelessWidget {
  const ButtonPair({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
        children: [Expanded(child: left), const SizedBox(width: 10), Expanded(child: right)],
      );
}

enum TagTone { green, blue, orange, red, gray, purple }

/// Selo pequeno (`.pill`).
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.tone = TagTone.blue});

  final String label;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final (bg, fg) = switch (tone) {
      TagTone.green => (c.greenSoft, c.green),
      TagTone.blue => (c.blueSoft, c.blue),
      TagTone.orange => (c.orangeSoft, c.orangeText),
      TagTone.red => (c.dangerSoft, c.danger),
      TagTone.gray => (c.neutralSoft, c.muted),
      TagTone.purple => (c.purpleSoft, c.purple),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.3)),
    );
  }
}

/// Título grande das abas (`.page-title`).
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 22, AppSpacing.page, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: context.bikoColors.ink),
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

/// Cabeçalho de seção com link opcional à direita ("Ver todas").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.trailing});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 22, AppSpacing.page, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.bikoColors.ink)),
            ),
            if (action != null) LinkText(action!, onTap: onAction),
            ?trailing,
          ],
        ),
      );
}

/// Texto azul clicável (`.link`).
class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, this.onTap, this.color, this.size = 13});

  final String text;
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Text(
            text,
            style: TextStyle(color: color ?? context.bikoColors.blue, fontWeight: FontWeight.w600, fontSize: size),
          ),
        ),
      );
}

/// Título dentro de um cartão (`.card-title`).
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.bikoColors.ink)),
            ),
            ?trailing,
          ],
        ),
      );
}

enum NoticeTone { warn, off, info }

/// Aviso em destaque (`.notice`): atraso, offline, modo rápido...
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.leading, required this.child, this.tone = NoticeTone.warn, this.onTap, this.margin});

  final Widget leading;
  final Widget child;
  final NoticeTone tone;
  final VoidCallback? onTap;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final (bg, border, fg) = switch (tone) {
      NoticeTone.warn => (c.warnBg, c.warnBorder, c.warnText),
      NoticeTone.off => (c.neutralSoft, c.line, c.muted),
      NoticeTone.info => (c.blueSoft, c.blueSoft, c.text),
    };
    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 14),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: fg, fontSize: 13, height: 1.45),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [leading, const SizedBox(width: 10), Expanded(child: child)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "🧪 Ambiente de demonstração (TCC)..." (`.demo-note`).
class DemoBanner extends StatelessWidget {
  const DemoBanner(this.text, {super.key, this.margin});

  final String text;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 14),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(color: c.purpleSoft, borderRadius: BorderRadius.circular(12)),
      child: Text('🧪 $text', style: TextStyle(color: c.purple, fontSize: 12, height: 1.4)),
    );
  }
}

/// Lista vazia (`.empty`).
class EmptyText extends StatelessWidget {
  const EmptyText(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
        child: Column(
          children: [
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.bikoColors.muted, fontSize: 14, height: 1.5)),
            if (action case final a?) ...[const SizedBox(height: 10), a],
          ],
        ),
      );
}

/// Linha "rótulo ........ valor" (`.kv`).
class KeyValue extends StatelessWidget {
  const KeyValue(this.label, this.value, {super.key, this.total = false, this.valueWidget});

  final String label;
  final String value;
  final bool total;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: total ? 0 : 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: total
                  ? TextStyle(color: c.ink, fontWeight: FontWeight.w700, fontSize: 16)
                  : TextStyle(color: c.text.withValues(alpha: 0.8), fontSize: 14),
            ),
          ),
          const SizedBox(width: 14),
          valueWidget ??
              Flexible(
                // Align: o valor fica colado à direita mesmo quando é curto.
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: total ? c.blue : c.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: total ? 20 : 14,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
    if (!total) return row;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: row,
    );
  }
}

/// Linha com ícone azul (`.line-ic`): relógio, endereço, telefone.
class IconLine extends StatelessWidget {
  const IconLine(this.icon, this.child, {super.key});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: context.bikoColors.blue)),
            const SizedBox(width: 10),
            Expanded(child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 14), child: child)),
          ],
        ),
      );
}

/// Separador fino dentro de cartões.
class ThinDivider extends StatelessWidget {
  const ThinDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: context.bikoColors.line));
}

/// Avatar: foto (se houver) ou as iniciais. Quadrado arredondado ou redondo, com anel azul opcional.
class BikoAvatar extends StatelessWidget {
  const BikoAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 46,
    this.square = false,
    this.ring = false,
    this.onlineDot = false,
    this.onHero = false,
  });

  final String name;
  final String? photoUrl;
  final double size;
  final bool square;
  final bool ring;

  /// Bolinha verde de "online" (prestadores no chat).
  final bool onlineDot;

  /// Avatar sobre o fundo azul (topo do admin).
  final bool onHero;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final t = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return t.isEmpty ? '?' : t;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final radius = square ? BorderRadius.circular(size * 0.24) : BorderRadius.circular(size);
    final initials = Container(
      alignment: Alignment.center,
      color: onHero ? Colors.white.withValues(alpha: 0.2) : (Theme.of(context).brightness == Brightness.dark ? c.blueSoft : const Color(0xFFDBE8FF)),
      child: Text(
        _initials,
        style: TextStyle(color: onHero ? Colors.white : c.blue, fontWeight: FontWeight.w700, fontSize: size * 0.33),
      ),
    );
    final url = photoUrl;
    Widget avatar = ClipRRect(
      borderRadius: radius,
      child: SizedBox.square(
        dimension: size,
        child: url == null ? initials : AuthImage(url: url, fallback: initials),
      ),
    );
    if (ring) {
      avatar = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: square ? BorderRadius.circular(size * 0.3) : BorderRadius.circular(size),
          border: Border.all(color: c.blue, width: 2),
        ),
        child: Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(color: c.card, borderRadius: square ? BorderRadius.circular(size * 0.27) : BorderRadius.circular(size)),
          child: avatar,
        ),
      );
    }
    if (onlineDot) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: AppColors.online, shape: BoxShape.circle, border: Border.all(color: c.card, width: 2)),
            ),
          ),
        ],
      );
    }
    return Semantics(label: url == null ? 'Avatar de $name' : 'Foto de $name', image: true, excludeSemantics: true, child: avatar);
  }
}

/// Selo de verificado (CPF conferido).
class VerifiedIcon extends StatelessWidget {
  const VerifiedIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.verified, size: size, color: context.bikoColors.blue, semanticLabel: 'Verificado');
}

/// "⭐ 4,8 · (12 avaliações)" ou o selo "Novo no Biko".
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.rating, required this.count});

  final double? rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    final r = rating;
    final c = context.bikoColors;
    if (r == null) return const Tag('Novo no Biko');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 18, color: AppColors.star),
        const SizedBox(width: 3),
        Text(Fmt.rating(r), style: TextStyle(fontWeight: FontWeight.w700, color: c.ink, fontSize: 13)),
        Text('  ·  ($count ${count == 1 ? 'avaliação' : 'avaliações'})', style: TextStyle(color: c.muted, fontSize: 13)),
      ],
    );
  }
}

/// Selo amarelo "⭐ 4,8 (12 avaliações)" do perfil.
class RatingPill extends StatelessWidget {
  const RatingPill({super.key, required this.rating, required this.count, this.emptyLabel = 'Novo no Biko'});

  final double? rating;
  final int count;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final r = rating;
    if (r == null) return Tag(emptyLabel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFFFF6E0), borderRadius: BorderRadius.circular(10)),
      child: Text(
        '⭐ ${Fmt.rating(r)} ($count ${count == 1 ? 'avaliação' : 'avaliações'})',
        style: const TextStyle(color: Color(0xFFB7791F), fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

/// Fileira de chips que rola na horizontal (`.chips`).
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page)});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), children[i]],
          ],
        ),
      );
}

/// Chip arredondado (`.chip`, `.chip.on`, `.chip.soft`).
class BikoChip extends StatelessWidget {
  const BikoChip({super.key, required this.label, this.selected = false, this.soft = false, this.icon, this.onTap});

  final String label;
  final bool selected;
  final bool soft;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    final (bg, border, fg) = selected
        ? (c.blue, c.blue, Colors.white)
        : soft
            ? (c.blueSoft, c.blueSoft, c.blue)
            : (c.card, c.line, c.text);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: border, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                Text(label, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Faixa de 14 dias para escolher a data (`.days`).
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelect,
    this.marked = const {},
    this.numberFirst = false,
  });

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  /// Dias com algum compromisso (bolinha laranja).
  final Set<String> marked;

  /// Agenda do prestador mostra o número em cima e o dia da semana embaixo.
  final bool numberFirst;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final on = Fmt.ymd(d) == Fmt.ymd(selected);
          final dot = on || marked.contains(Fmt.ymd(d));
          final dow = Text(
            Fmt.weekday(d),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: on ? Colors.white : c.muted),
          );
          final num = Text('${d.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: on ? Colors.white : c.ink));
          return Semantics(
            button: true,
            selected: on,
            label: '${Fmt.weekday(d)} ${d.day}',
            excludeSemantics: true,
            child: Material(
              color: on ? c.blue : c.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: on ? c.blue : c.line, width: 1.5),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelect(d),
                child: SizedBox(
                  width: 58,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (numberFirst) num else dow,
                      if (numberFirst) dow else num,
                      const SizedBox(height: 5),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: dot ? c.orange : Colors.transparent, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Botão redondo de ícone (`.icon-btn.soft.round`).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip, this.orange = false});

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool orange;

  @override
  Widget build(BuildContext context) {
    final c = context.bikoColors;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: orange ? c.orangeSoft : c.blueSoft,
        foregroundColor: orange ? c.orange : c.blue,
        fixedSize: const Size(42, 42),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

/// Moldura das telas: rolagem, "puxar para atualizar" e largura máxima em telas largas.
class BikoPage extends StatelessWidget {
  const BikoPage({super.key, required this.children, this.onRefresh, this.bottomPadding = 18});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomPadding),
      children: [
        for (final child in children)
          Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: AppSizes.pageMaxWidth), child: child),
          ),
      ],
    );
    final refresh = onRefresh;
    return refresh == null ? list : RefreshIndicator(onRefresh: refresh, child: list);
  }
}

/// Barra de cima das telas empilhadas (`.topbar`): voltar + título.
PreferredSizeWidget bikoAppBar(BuildContext context, String title, {bool left = false, List<Widget>? actions, Color? background}) {
  final c = context.bikoColors;
  return AppBar(
    backgroundColor: background ?? c.background,
    centerTitle: !left,
    titleSpacing: left ? 0 : null,
    leading: Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Center(
        child: SizedBox.square(
          dimension: 42,
          child: Material(
            color: c.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.line)),
            child: const BackButton(),
          ),
        ),
      ),
    ),
    leadingWidth: 62,
    title: Text(
      title,
      style: TextStyle(fontWeight: left ? FontWeight.w700 : FontWeight.w600, fontSize: left ? 19 : 15.5, color: c.ink),
    ),
    actions: actions,
  );
}

/// Abre uma folha que sobe do rodapé (`.sheet`), com rolagem e teclado.
Future<T?> showBikoSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
          child: builder(sheetContext),
        ),
      ),
    );

/// Título de uma folha.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(child: Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.bikoColors.ink))),
            ?trailing,
          ],
        ),
      );
}

/// Rótulo acima de um campo (`label.lbl`).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.bikoColors.text)),
            ),
            ?trailing,
          ],
        ),
      );
}

/// Logo do Figma: quadrado azul com o "B" branco.
class BikoLogoMark extends StatelessWidget {
  const BikoLogoMark({super.key, this.size = 70, this.shadow = true, this.bordered = false});

  final double size;
  final bool shadow;
  final bool bordered;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Biko',
        excludeSemantics: true,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2F8CFF), Color(0xFF0060E0)]),
            border: bordered ? Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2) : null,
            boxShadow: shadow ? [BoxShadow(color: AppColors.brandBlue.withValues(alpha: 0.35), blurRadius: 26, offset: const Offset(0, 12))] : null,
          ),
          child: Text('B', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.46, height: 1)),
        ),
      );
}

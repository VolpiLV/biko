import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/theme_view_model.dart';

/// Menu da AppBar para escolher Claro / Escuro / Sistema.
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  static const Map<ThemeMode, (String, IconData)> _options = {
    ThemeMode.light: ('Claro', Icons.light_mode_outlined),
    ThemeMode.dark: ('Escuro', Icons.dark_mode_outlined),
    ThemeMode.system: ('Padrão do sistema', Icons.brightness_auto_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final current = context.select<ThemeViewModel, ThemeMode>((vm) => vm.mode);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Tema',
      icon: Icon(_options[current]?.$2 ?? Icons.brightness_auto_outlined),
      initialValue: current,
      onSelected: (mode) => context.read<ThemeViewModel>().setMode(mode),
      itemBuilder: (context) => [
        for (final MapEntry(key: mode, value: (label, icon)) in _options.entries)
          CheckedPopupMenuItem<ThemeMode>(
            value: mode,
            checked: mode == current,
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 12),
                Flexible(child: Text(label)),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/theme_view_model.dart';

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeViewModel>();
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Aparência',
      initialValue: theme.themeMode,
      onSelected: (mode) => theme.setDarkMode(mode == ThemeMode.dark),
      icon: Icon(theme.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ThemeMode.light,
          child: Row(
            children: [
              const Icon(Icons.light_mode_outlined),
              const SizedBox(width: 12),
              const Text('Modo claro'),
              if (theme.themeMode == ThemeMode.light) ...[
                const Spacer(),
                const Icon(Icons.check, size: 18),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.dark,
          child: Row(
            children: [
              const Icon(Icons.dark_mode_outlined),
              const SizedBox(width: 12),
              const Text('Modo escuro'),
              if (theme.themeMode == ThemeMode.dark) ...[
                const Spacer(),
                const Icon(Icons.check, size: 18),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

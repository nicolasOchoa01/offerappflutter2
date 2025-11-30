
import 'package:flutter/material.dart';

class CustomHeader extends StatelessWidget implements PreferredSizeWidget {
  final String username;
  final VoidCallback onProfileClick;
  final VoidCallback onSessionClicked;
  final String? title;
  final String? query;
  final ValueChanged<String>? onQueryChange;
  final VoidCallback? onBackClicked;
  final VoidCallback? onMenuClick;
  final VoidCallback? onLogoClick;

  const CustomHeader({
    super.key,
    required this.username,
    required this.onProfileClick,
    required this.onSessionClicked,
    this.title,
    this.query,
    this.onQueryChange,
    this.onBackClicked,
    this.onMenuClick,
    this.onLogoClick,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconTint = colorScheme.onPrimary;

    Widget? leading;
    if (onMenuClick != null) {
      leading = IconButton(
        icon: Icon(Icons.menu, color: iconTint),
        onPressed: onMenuClick,
        tooltip: 'Menú',
      );
    } else if (onBackClicked != null) {
      leading = IconButton(
        icon: Icon(Icons.arrow_back, color: iconTint),
        onPressed: onBackClicked,
        tooltip: 'Volver',
      );
    }

    Widget titleWidget;
    if (query != null && onQueryChange != null) {
      titleWidget = _SearchBar(
        query: query!,
        onQueryChange: onQueryChange!,
      );
    } else if (title != null) {
      titleWidget = Text(
        title!,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: iconTint,
              fontWeight: FontWeight.bold,
            ),
      );
    } else {
      titleWidget = const Spacer();
    }

    return AppBar(
      leading: leading,
      title: Row(
        children: [
          if (onLogoClick != null)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onLogoClick,
                child: Row(
                  children: [
                    Icon(Icons.local_offer_outlined, color: iconTint, size: 32),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          Expanded(child: titleWidget),
        ],
      ),
      backgroundColor: colorScheme.primary,
      elevation: 4,
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'profile') {
              onProfileClick();
            } else if (value == 'logout') {
              onSessionClicked();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'username',
              enabled: false,
              child: Text('Hola, $username', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'profile',
              child: Text('Ver Perfil'),
            ),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Text('Cerrar Sesión'),
            ),
          ],
          icon: Icon(Icons.person, color: iconTint),
          tooltip: 'Perfil / Cerrar Sesión',
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SearchBar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onQueryChange;

  const _SearchBar({required this.query, required this.onQueryChange});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: TextField(
        onChanged: onQueryChange,
        controller: TextEditingController(text: query),
        decoration: InputDecoration(
          hintText: 'Buscar productos...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

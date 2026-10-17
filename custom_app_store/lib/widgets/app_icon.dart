import 'package:flutter/material.dart';

import '../models/store_app.dart';

/// Displays an app icon from a URL with a graceful letter-avatar fallback.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.app, this.size = 48, this.radius = 12});

  final StoreApp app;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        _initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );

    if (app.icon.isEmpty) {
      return ClipRRect(borderRadius: BorderRadius.circular(radius), child: fallback);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        app.icon,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return fallback;
        },
      ),
    );
  }

  String get _initial {
    final name = app.name.trim();
    if (name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }
}

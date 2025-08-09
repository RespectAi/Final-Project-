// lib/widgets/common.dart
import 'package:flutter/material.dart';

const Color kGradientStart = Color(0xFF2E7D32);
const Color kGradientEnd = Color(0xFF0277BD);

PreferredSizeWidget buildGradientAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
  bool showBackIfCanPop = true,
}) {
  return AppBar(
    title: Text(title),
    elevation: 0,
    centerTitle: true,
    backgroundColor: Colors.transparent,
    leading: showBackIfCanPop && Navigator.of(context).canPop()
        ? const BackButton()
        : null,
    actions: actions,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kGradientStart, kGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
    ),
  );
}

// Backwards-compat alias (without context). Keeps existing calls working.
PreferredSizeWidget gradientAppBar(String title) {
  return AppBar(
    title: Text(title),
    elevation: 0,
    centerTitle: true,
    backgroundColor: Colors.transparent,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kGradientStart, kGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
    ),
  );
}

// Small top-corner toast popup that auto-dismisses
void showCornerToast(
  BuildContext context, {
  required String message,
  Alignment alignment = Alignment.topRight,
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => SafeArea(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(duration, () {
    entry.remove();
  });
}

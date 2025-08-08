// lib/widgets/common.dart
import 'package:flutter/material.dart';

const Color kGradientStart = Color(0xFF2E7D32);
const Color kGradientEnd = Color(0xFF0277BD);

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

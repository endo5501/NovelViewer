import 'package:flutter/material.dart';

/// Small outlined pill badge rendered in the theme's disabled color, used for
/// compact status labels such as "未追跡" (untracked) in the history list and
/// "無効" (invalid) in the detail dialog's facts tab.
class OutlinedTextBadge extends StatelessWidget {
  const OutlinedTextBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).disabledColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }
}

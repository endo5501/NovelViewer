import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A [TabBar] of text labels that spreads its tabs over the width it is given,
/// as a plain [TabBar] does, until the labels no longer fit; then it scrolls
/// instead.
///
/// A fixed tab bar shares the width equally and fades out whatever label is
/// longer than its share, which on a phone leaves a label such as
/// "ブックマーク" unreadable. Always scrolling would avoid that but would also
/// bunch the tabs up at the start of a wide display, so the choice is made
/// from the width the labels actually need.
class FittingTabBar extends StatelessWidget {
  const FittingTabBar({
    super.key,
    required this.controller,
    required this.labels,
  });

  final TabController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollable =
            _widestTabWidth(context) * labels.length > constraints.maxWidth;
        return TabBar(
          controller: controller,
          isScrollable: scrollable,
          tabAlignment: scrollable ? TabAlignment.start : null,
          tabs: [for (final label in labels) Tab(text: label)],
        );
      },
    );
  }

  /// The width of the widest tab, label and the padding the [TabBar] puts
  /// around it. A fixed tab bar gives every tab the same share, so the labels
  /// fit only when that share holds the widest of them. A label is measured in
  /// both its selected and unselected style, since either can be the wider.
  double _widestTabWidth(BuildContext context) {
    final tabBarTheme = TabBarTheme.of(context);
    final defaultStyle = Theme.of(context).textTheme.titleSmall;
    final styles = {
      tabBarTheme.labelStyle ?? defaultStyle,
      tabBarTheme.unselectedLabelStyle ??
          tabBarTheme.labelStyle ??
          defaultStyle,
    };
    final padding = (tabBarTheme.labelPadding ?? kTabLabelPadding).horizontal;
    final textScaler = MediaQuery.textScalerOf(context);
    var width = 0.0;
    for (final label in labels) {
      for (final style in styles) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        width = math.max(width, painter.width + padding);
        painter.dispose();
      }
    }
    return width;
  }
}

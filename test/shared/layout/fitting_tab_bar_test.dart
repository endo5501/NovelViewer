import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/layout/fitting_tab_bar.dart';

void main() {
  const labels = ['ファイル', 'ブックマーク', '解析履歴', 'アプリ情報 / 更新'];

  Future<TabBar> pumpTabBar(
    WidgetTester tester, {
    required double width,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: DefaultTabController(
                length: labels.length,
                child: Builder(
                  builder: (context) => FittingTabBar(
                    controller: DefaultTabController.of(context),
                    labels: labels,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return tester.widget<TabBar>(find.byType(TabBar));
  }

  testWidgets('spreads the tabs over the width when the labels fit', (
    tester,
  ) async {
    final tabBar = await pumpTabBar(tester, width: 760);

    expect(tabBar.isScrollable, isFalse);
  });

  testWidgets('scrolls the tabs when the labels do not fit', (tester) async {
    final tabBar = await pumpTabBar(tester, width: 260);

    expect(tabBar.isScrollable, isTrue);
    expect(tabBar.tabAlignment, TabAlignment.start);
  });

  testWidgets('shows every label it is given', (tester) async {
    await pumpTabBar(tester, width: 260);

    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('counts the label padding the theme gives the tabs', (
    tester,
  ) async {
    // Wide enough for the labels with the default padding, too narrow once
    // the theme pads every label by 48 on each side.
    final plain = await pumpTabBar(tester, width: 760);
    expect(plain.isScrollable, isFalse);

    final padded = await pumpTabBar(
      tester,
      width: 760,
      theme: ThemeData(
        tabBarTheme: const TabBarThemeData(
          labelPadding: EdgeInsets.symmetric(horizontal: 48),
        ),
      ),
    );

    expect(padded.isScrollable, isTrue);
  });

  testWidgets('counts a larger style for the unselected labels', (
    tester,
  ) async {
    final tabBar = await pumpTabBar(
      tester,
      width: 760,
      theme: ThemeData(
        tabBarTheme: const TabBarThemeData(
          unselectedLabelStyle: TextStyle(fontSize: 40),
        ),
      ),
    );

    expect(tabBar.isScrollable, isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/layout/fitting_tab_bar.dart';

void main() {
  const labels = ['ファイル', 'ブックマーク', '解析履歴', 'アプリ情報 / 更新'];

  Future<TabBar> pumpTabBar(
    WidgetTester tester, {
    required double width,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
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
}

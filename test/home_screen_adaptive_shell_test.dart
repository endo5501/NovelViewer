import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/shared/providers/layout_providers.dart';

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(NovelViewerApp)));

/// Walks up the focus tree looking for a node whose debugLabel marks a pane.
bool paneHasFocus(WidgetTester tester, String label) {
  FocusNode? node = tester.binding.focusManager.primaryFocus;
  while (node != null) {
    if (node.debugLabel == label) return true;
    node = node.parent;
  }
  return false;
}

Future<void> pressSearchShortcut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pumpAndSettle();
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Mounts the app. The test viewport is 800x600, so leaving the breakpoint
  /// alone renders the wide layout; overriding it above 800 renders the narrow
  /// one without resizing the surface.
  /// The breakpoint is always overridden — with its own default value unless a
  /// test asks for another — because Riverpod forbids changing the *number* of
  /// overrides across pumps, and some tests mount both layouts in turn.
  Future<void> pumpApp(WidgetTester tester, {double breakpoint = 800}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/library'),
          shellBreakpointProvider.overrideWithValue(breakpoint),
        ],
        child: const NovelViewerApp(),
      ),
    );
  }

  group('narrow layout', () {
    testWidgets('gives the whole body to the text viewer', (tester) async {
      await pumpApp(tester, breakpoint: 900);

      expect(find.byKey(const Key('center_column')), findsOneWidget);
      expect(find.byKey(const Key('left_column')), findsNothing);
      expect(find.byKey(const Key('right_column')), findsNothing);
      expect(find.byType(VerticalDivider), findsNothing);
    });

    testWidgets('holds the left column in a drawer at its usual width', (
      tester,
    ) async {
      await pumpApp(tester, breakpoint: 900);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('left_column')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('left_column'))).width, 250);
    });
  });

  group('drawer gestures', () {
    testWidgets('an edge drag does not open the drawer', (tester) async {
      // The vertical viewer reads a horizontal drag as a page turn, so a
      // drawer that opened on an edge drag would take page turning away at
      // exactly the edges of the screen.
      await pumpApp(tester, breakpoint: 900);

      await tester.dragFrom(const Offset(1, 300), const Offset(300, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('left_column')), findsNothing);
    });

    testWidgets('the app bar button opens the drawer', (tester) async {
      await pumpApp(tester, breakpoint: 900);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('left_column')), findsOneWidget);
    });
  });

  testWidgets(
    'an actual iPad mini portrait viewport selects the narrow layout',
    (tester) async {
      // The other narrow tests override the breakpoint instead of resizing the
      // surface. This one does it the hard way once, so a mistake in how the
      // width is read cannot hide behind that convenience.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(744, 1133);
      addTearDown(tester.view.reset);

      await pumpApp(tester);

      expect(find.byKey(const Key('center_column')), findsOneWidget);
      expect(find.byKey(const Key('left_column')), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    },
  );

  group('the right column as an end drawer', () {
    testWidgets('opens when the visibility state becomes true', (tester) async {
      await pumpApp(tester, breakpoint: 900);

      containerOf(tester).read(rightColumnVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('right_column')), findsOneWidget);
      // The viewer keeps the whole body underneath; the panel is an overlay.
      expect(find.byKey(const Key('center_column')), findsOneWidget);
    });

    testWidgets('dismissing it by the scrim clears the visibility state', (
      tester,
    ) async {
      await pumpApp(tester, breakpoint: 900);
      final container = containerOf(tester);

      container.read(rightColumnVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(100, 300));
      await tester.pumpAndSettle();

      expect(container.read(rightColumnVisibleProvider), isFalse);
      expect(find.byKey(const Key('right_column')), findsNothing);
    });

    testWidgets('reopens after being dismissed', (tester) async {
      await pumpApp(tester, breakpoint: 900);
      final container = containerOf(tester);

      container.read(rightColumnVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(100, 300));
      await tester.pumpAndSettle();
      container.read(rightColumnVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('right_column')), findsOneWidget);
    });

    testWidgets('an edge drag does not open it', (tester) async {
      await pumpApp(tester, breakpoint: 900);

      await tester.dragFrom(const Offset(799, 300), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('right_column')), findsNothing);
    });
  });

  group('the search session in the narrow layout', () {
    testWidgets('the shortcut opens the end drawer and closes it again', (
      tester,
    ) async {
      await pumpApp(tester, breakpoint: 900);
      final container = containerOf(tester);

      await pressSearchShortcut(tester);
      expect(find.byKey(const Key('right_column')), findsOneWidget);
      expect(container.read(rightColumnVisibleProvider), isTrue);

      await pressSearchShortcut(tester);
      expect(find.byKey(const Key('right_column')), findsNothing);
      expect(container.read(rightColumnVisibleProvider), isFalse);
    });

    testWidgets('a selection search opens the end drawer', (tester) async {
      await pumpApp(tester, breakpoint: 900);
      final container = containerOf(tester);

      container
          .read(selectedTextProvider.notifier)
          .setSelection(const ViewerSelection(text: '太郎', plainTextOffset: 0));
      await pressSearchShortcut(tester);

      expect(container.read(searchQueryProvider), '太郎');
      expect(find.byKey(const Key('right_column')), findsOneWidget);
    });

    testWidgets('Escape closes a selection search and its drawer', (
      tester,
    ) async {
      await pumpApp(tester, breakpoint: 900);
      final container = containerOf(tester);

      container
          .read(selectedTextProvider.notifier)
          .setSelection(const ViewerSelection(text: '太郎', plainTextOffset: 0));
      await pressSearchShortcut(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(container.read(searchQueryProvider), isNull);
      expect(container.read(rightColumnVisibleProvider), isFalse);
      expect(find.byKey(const Key('right_column')), findsNothing);
    });
  });

  group('closing a drawer that has stopped being useful', () {
    testWidgets('selecting a file closes the drawer', (tester) async {
      // Otherwise the reader picks an episode and is left looking at the file
      // list, with the text they asked for hidden behind it.
      await pumpApp(tester, breakpoint: 900);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('left_column')), findsOneWidget);

      containerOf(tester)
          .read(selectedFileProvider.notifier)
          .selectFile(
            const FileEntry(name: '001.txt', path: '/library/001.txt'),
          );
      // Not pumpAndSettle: loading the file leaves a progress indicator
      // spinning, so the frame stream never quiesces. The drawer's close
      // animation is well under 400ms.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('left_column')), findsNothing);
    });

    testWidgets('re-selecting the same file still closes the drawer', (
      tester,
    ) async {
      // The file list hands back the cached FileEntry, so tapping the episode
      // already open sets the provider to a value it considers unchanged and
      // no listener fires. The reader would be left staring at the list.
      await pumpApp(tester, breakpoint: 900);
      final container = containerOf(tester);
      const entry = FileEntry(name: '001.txt', path: '/library/001.txt');
      container.read(selectedFileProvider.notifier).selectFile(entry);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('left_column')), findsOneWidget);

      container.read(selectedFileProvider.notifier).selectFile(entry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('left_column')), findsNothing);
    });

    testWidgets('clearing the selection leaves the drawer open', (
      tester,
    ) async {
      // Entering a folder clears the selection (file_browser_panel), and the
      // reader is still choosing. Closing there would shut the drawer under
      // the very tap that opened the folder.
      await pumpApp(tester, breakpoint: 900);
      final container = containerOf(tester);
      container
          .read(selectedFileProvider.notifier)
          .selectFile(
            const FileEntry(name: '001.txt', path: '/library/001.txt'),
          );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.menu));
      // Not pumpAndSettle: the selected file leaves a progress indicator
      // spinning, so the frame stream never quiesces.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('left_column')), findsOneWidget);

      container.read(selectedFileProvider.notifier).clear();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('left_column')), findsOneWidget);
    });

    testWidgets('widening past the breakpoint closes an open drawer', (
      tester,
    ) async {
      // Standing in for a rotation on an iPad: the display grows past the
      // breakpoint while a drawer is open, and the layout that owned it goes
      // away.
      await pumpApp(tester, breakpoint: 900);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('left_column')), findsOneWidget);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 600);
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsNothing);
      expect(find.byKey(const Key('left_column')), findsOneWidget);
      expect(find.byKey(const Key('center_column')), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNWidgets(1));
    });

    testWidgets('widening keeps an open search session', (tester) async {
      // The end drawer disappears with the narrow layout, and its dismissal
      // callback must not be mistaken for the reader closing the search.
      await pumpApp(tester, breakpoint: 900);
      final container = containerOf(tester);

      container.read(rightColumnVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('right_column')), findsOneWidget);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 600);
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      expect(container.read(rightColumnVisibleProvider), isTrue);
      expect(find.byKey(const Key('right_column')), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(VerticalDivider), findsNWidgets(2));
    });
  });

  group('crossing the breakpoint', () {
    Future<void> resize(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 600);
      await tester.pumpAndSettle();
    }

    testWidgets('narrowing shows an already-open search as the end drawer', (
      tester,
    ) async {
      // The visibility state does not change across the rotation, so nothing
      // tells the newly created drawer to open. Without a reconcile the reader
      // is left with a search that the app believes is showing and that is
      // nowhere on screen.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 600);
      addTearDown(tester.view.reset);
      await pumpApp(tester, breakpoint: 900);
      final container = containerOf(tester);

      container.read(rightColumnVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('right_column')), findsOneWidget);

      await resize(tester, 800);

      expect(container.read(rightColumnVisibleProvider), isTrue);
      expect(find.byKey(const Key('right_column')), findsOneWidget);
    });

    testWidgets('returning to narrow does not resurrect a closed search', (
      tester,
    ) async {
      // The scaffold remembers that its end drawer was open and hands that
      // flag to the replacement it builds, so a drawer torn down while open
      // can come back open even though the reader has since closed the search.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      await pumpApp(tester, breakpoint: 900);
      final container = containerOf(tester);

      container.read(rightColumnVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('right_column')), findsOneWidget);

      await resize(tester, 1000);
      container.read(rightColumnVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('right_column')), findsNothing);

      await resize(tester, 800);

      expect(container.read(rightColumnVisibleProvider), isFalse);
      expect(find.byKey(const Key('right_column')), findsNothing);
    });
  });

  group('the app bar', () {
    testWidgets('offers a search button in both layouts', (tester) async {
      // A tablet without a keyboard has no Ctrl/Cmd+F, so the shortcut cannot
      // be the only way in.
      await pumpApp(tester);
      expect(find.byKey(const Key('search_button')), findsOneWidget);

      await pumpApp(tester, breakpoint: 900);
      expect(find.byKey(const Key('search_button')), findsOneWidget);
    });

    testWidgets('the search button opens the end drawer in the narrow layout', (
      tester,
    ) async {
      await pumpApp(tester, breakpoint: 900);
      final container = containerOf(tester);

      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();

      expect(container.read(rightColumnVisibleProvider), isTrue);
      expect(find.byKey(const Key('right_column')), findsOneWidget);
    });

    testWidgets('the search button toggles the session in the wide layout', (
      tester,
    ) async {
      // Only the wide layout can close it this way: an open end drawer covers
      // the right of the app bar, so the button is out of reach there and the
      // reader dismisses the drawer itself instead.
      await pumpApp(tester);
      final container = containerOf(tester);

      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();
      expect(container.read(rightColumnVisibleProvider), isTrue);
      expect(find.byKey(const Key('right_column')), findsOneWidget);

      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();
      expect(container.read(rightColumnVisibleProvider), isFalse);
      expect(find.byKey(const Key('right_column')), findsNothing);
    });

    testWidgets('the search button reopens after the drawer was dismissed', (
      tester,
    ) async {
      // Dismissing the drawer must end the whole search session. If only the
      // column visibility were cleared, the next press would take the "close
      // an active search" branch and appear to do nothing — on the one entry
      // point a tablet without a keyboard has.
      await pumpApp(tester, breakpoint: 900);
      final container = containerOf(tester);

      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('right_column')), findsOneWidget);

      await tester.tapAt(const Offset(100, 300));
      await tester.pumpAndSettle();
      expect(container.read(searchBoxVisibleProvider), isFalse);

      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('right_column')), findsOneWidget);
    });

    testWidgets('the search button searches the current selection', (
      tester,
    ) async {
      await pumpApp(tester);
      final container = containerOf(tester);

      container
          .read(selectedTextProvider.notifier)
          .setSelection(const ViewerSelection(text: '太郎', plainTextOffset: 0));
      await tester.tap(find.byKey(const Key('search_button')));
      await tester.pumpAndSettle();

      expect(container.read(searchQueryProvider), '太郎');
    });

    testWidgets('the column toggle is present only in the wide layout', (
      tester,
    ) async {
      // In the narrow layout it would be a second button opening the same end
      // drawer, labelled as showing a column that is not on screen.
      await pumpApp(tester);
      expect(
        find.byKey(const Key('toggle_right_column_button')),
        findsOneWidget,
      );

      await pumpApp(tester, breakpoint: 900);
      expect(find.byKey(const Key('toggle_right_column_button')), findsNothing);
    });
  });

  group('pane switching', () {
    testWidgets('Tab still switches panes in the wide layout', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      expect(paneHasFocus(tester, 'fileBrowserPane'), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(paneHasFocus(tester, 'novelPane'), isTrue);
    });

    testWidgets('Tab is left to normal traversal in the narrow layout', (
      tester,
    ) async {
      // The file browser pane lives in a closed drawer, so a registered
      // switchPane would swallow the key press and move focus nowhere — for an
      // action the reader can neither see nor rebind.
      await pumpApp(tester, breakpoint: 900);
      await tester.pumpAndSettle();
      final before = tester.binding.focusManager.primaryFocus;

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        tester.binding.focusManager.primaryFocus,
        isNot(before),
        reason: 'an unregistered Tab falls through to focus traversal',
      );
    });

    testWidgets('no pane holds focus at launch in the narrow layout', (
      tester,
    ) async {
      await pumpApp(tester, breakpoint: 900);
      await tester.pumpAndSettle();

      expect(paneHasFocus(tester, 'fileBrowserPane'), isFalse);
    });
  });

  group('wide layout', () {
    testWidgets('keeps the three-column row and has no drawer', (tester) async {
      await pumpApp(tester);

      expect(find.byKey(const Key('left_column')), findsOneWidget);
      expect(find.byKey(const Key('center_column')), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNWidgets(1));
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.byType(Drawer), findsNothing);
    });
  });
}

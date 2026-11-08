import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A tooltip whose route is not the current one is Covered: it hides, however
/// it was opened, and does not show until its route is current again
/// (ADR-0011).
void main() {
  final tip = find.byKey(const Key('tip'));
  final label = find.byKey(const Key('label'));

  /// Whether the tooltip is on screen, including under an opaque route that
  /// has taken the route below offstage.
  bool tipInTree() =>
      find.byKey(const Key('tip'), skipOffstage: false).evaluate().isNotEmpty;

  /// The scheduler phase each `onHide` from [rowApp] ran in.
  final phases = <SchedulerPhase>[];
  setUp(phases.clear);

  /// A tooltip on a label inside a tappable row whose tap opens a route, the
  /// shape of #100's report.
  Widget rowApp({
    required List<String> log,
    required Route<void> Function(BuildContext) route,
    JustTooltipController? controller,
    bool hideWhenCovered = true,
    TooltipTap tap = TooltipTap.observe,
    bool enableHover = false,
    Duration animationDuration = const Duration(milliseconds: 150),
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(route(context)),
              child: SizedBox(
                width: 600,
                height: 60,
                child: Align(
                  child: JustTooltip(
                    controller: controller,
                    tap: tap,
                    enableHover: enableHover,
                    hideWhenCovered: hideWhenCovered,
                    animationDuration: animationDuration,
                    onShow: () => log.add('show'),
                    onHide: () {
                      log.add('hide');
                      phases.add(SchedulerBinding.instance.schedulerPhase);
                    },
                    tooltipBuilder: (_) =>
                        const SizedBox(key: Key('tip'), width: 100, height: 40),
                    child: const SizedBox(
                      key: Key('label'),
                      width: 400,
                      height: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Route<void> dialogRoute(BuildContext context) => DialogRoute<void>(
    context: context,
    builder: (_) => const AlertDialog(content: Text('dialog')),
  );

  Route<void> pageRoute(BuildContext _) => MaterialPageRoute<void>(
    builder: (_) => const Scaffold(body: Text('page')),
  );

  NavigatorState navigator(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator));

  /// A context under the app's [Navigator], for building a route to push.
  BuildContext home(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  group('a route pushed over a shown tooltip', () {
    testWidgets('a dialog opened by the same tap keeps it from opening, and '
        'the pop does not bring it back', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(rowApp(log: log, route: dialogRoute));

      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(find.text('dialog'), findsOneWidget);
      expect(tipInTree(), isFalse);
      expect(log, isEmpty);

      navigator(tester).pop();
      await tester.pumpAndSettle();
      expect(tipInTree(), isFalse);
      expect(log, isEmpty);
    });

    testWidgets('a page opened by the same tap keeps it from opening, and the '
        'pop does not bring it back', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(rowApp(log: log, route: pageRoute));

      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(find.text('page'), findsOneWidget);
      expect(tipInTree(), isFalse);
      expect(log, isEmpty);

      navigator(tester).pop();
      await tester.pumpAndSettle();
      expect(tipInTree(), isFalse);
      expect(log, isEmpty);
    });

    testWidgets('a push with no pointer hides a controller-shown tooltip', (
      tester,
    ) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        rowApp(
          log: log,
          route: pageRoute,
          controller: controller,
          tap: TooltipTap.none,
        ),
      );
      controller.show();
      await tester.pumpAndSettle();
      expect(tip, findsOneWidget);

      navigator(tester).push(pageRoute(home(tester)));
      await tester.pumpAndSettle();
      expect(tipInTree(), isFalse);
      expect(controller.isShowing, isFalse);
      expect(log, ['show', 'hide']);

      navigator(tester).pop();
      await tester.pumpAndSettle();
      expect(tipInTree(), isFalse);
      expect(log, ['show', 'hide']);
    });

    testWidgets('a hide begun by the covering frame calls onHide after that '
        'frame', (tester) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        rowApp(
          log: log,
          route: pageRoute,
          controller: controller,
          tap: TooltipTap.none,
          animationDuration: Duration.zero,
        ),
      );
      controller.show();
      await tester.pumpAndSettle();

      navigator(tester).push(dialogRoute(home(tester)));
      await tester.pumpAndSettle();
      expect(log, ['show', 'hide']);
      expect(phases, isNot(contains(SchedulerPhase.persistentCallbacks)));
    });

    testWidgets('a dialog pushed with no pointer hides a controller-shown '
        'tooltip', (tester) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        rowApp(
          log: log,
          route: pageRoute,
          controller: controller,
          tap: TooltipTap.none,
        ),
      );
      controller.show();
      await tester.pumpAndSettle();
      expect(tip, findsOneWidget);

      navigator(tester).push(dialogRoute(home(tester)));
      await tester.pumpAndSettle();
      expect(tipInTree(), isFalse);
      expect(log, ['show', 'hide']);
    });

    testWidgets('a popup menu hides a tooltip on the route below', (
      tester,
    ) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        rowApp(
          log: log,
          route: pageRoute,
          controller: controller,
          tap: TooltipTap.none,
        ),
      );
      controller.show();
      await tester.pumpAndSettle();
      expect(tip, findsOneWidget);

      showMenu<void>(
        context: tester.element(label),
        position: const RelativeRect.fromLTRB(10, 10, 10, 10),
        items: const [PopupMenuItem<void>(child: Text('item'))],
      );
      await tester.pumpAndSettle();
      expect(find.text('item'), findsOneWidget);
      expect(tipInTree(), isFalse);
      expect(log, ['show', 'hide']);
    });

    testWidgets('a long fade under an opaque page still ends in onHide before '
        'the pop', (tester) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        rowApp(
          log: log,
          route: pageRoute,
          controller: controller,
          tap: TooltipTap.none,
          animationDuration: const Duration(seconds: 2),
        ),
      );
      controller.show();
      await tester.pumpAndSettle();

      navigator(tester).push(pageRoute(home(tester)));
      await tester.pumpAndSettle();
      // Settled with the page on top and the route below offstage.
      expect(find.text('page'), findsOneWidget);
      expect(log, ['show', 'hide']);
    });
  });

  group('in the same handler as the navigation', () {
    testWidgets('a show right after a pop shows the tooltip', (tester) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        rowApp(
          log: log,
          route: pageRoute,
          controller: controller,
          tap: TooltipTap.none,
        ),
      );
      navigator(tester).push(dialogRoute(home(tester)));
      await tester.pumpAndSettle();

      navigator(tester).pop();
      controller.show();
      await tester.pumpAndSettle();
      expect(tip, findsOneWidget);
      expect(log, ['show']);
    });

    testWidgets('a show right after a push shows nothing', (tester) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        rowApp(
          log: log,
          route: pageRoute,
          controller: controller,
          tap: TooltipTap.none,
        ),
      );

      navigator(tester).push(dialogRoute(home(tester)));
      controller.show();
      await tester.pumpAndSettle();
      expect(tipInTree(), isFalse);
      expect(log, isEmpty);
    });
  });

  group('while covered', () {
    testWidgets('controller.show() shows nothing, and the pop does not bring '
        'it back', (tester) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        rowApp(
          log: log,
          route: pageRoute,
          controller: controller,
          tap: TooltipTap.none,
        ),
      );
      navigator(tester).push(dialogRoute(home(tester)));
      await tester.pumpAndSettle();

      controller.show();
      await tester.pumpAndSettle();
      expect(tipInTree(), isFalse);
      expect(controller.isShowing, isFalse);

      navigator(tester).pop();
      await tester.pumpAndSettle();
      expect(tipInTree(), isFalse);
      expect(log, isEmpty);
    });

    testWidgets('a show queued before attach is dropped', (tester) async {
      final log = <String>[];
      final controller = JustTooltipController()..show();
      final withTooltip = ValueNotifier(false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: withTooltip,
                builder: (_, on, _) => on
                    ? JustTooltip(
                        controller: controller,
                        onShow: () => log.add('show'),
                        onHide: () => log.add('hide'),
                        tooltipBuilder: (_) => const SizedBox(
                          key: Key('tip'),
                          width: 100,
                          height: 40,
                        ),
                        child: const SizedBox(
                          key: Key('label'),
                          width: 60,
                          height: 30,
                        ),
                      )
                    : const SizedBox(),
              ),
            ),
          ),
        ),
      );
      navigator(tester).push(dialogRoute(home(tester)));
      await tester.pumpAndSettle();

      withTooltip.value = true;
      await tester.pumpAndSettle();
      expect(tipInTree(), isFalse);

      navigator(tester).pop();
      await tester.pumpAndSettle();
      expect(tipInTree(), isFalse);
      expect(log, isEmpty);
    });
  });

  group('not a dismissal', () {
    for (final duration in [const Duration(milliseconds: 150), Duration.zero]) {
      testWidgets('a trigger still inside the child shows it again once its '
          'route is current (fade $duration)', (tester) async {
        final log = <String>[];
        final node = FocusNode();
        addTearDown(node.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: JustTooltip(
                  enableFocus: true,
                  animationDuration: duration,
                  onShow: () => log.add('show'),
                  onHide: () => log.add('hide'),
                  tooltipBuilder: (_) =>
                      const SizedBox(key: Key('tip'), width: 100, height: 40),
                  child: TextButton(
                    focusNode: node,
                    onPressed: () {},
                    child: const Text('btn'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(node.hasFocus, isTrue);
        expect(tip, findsOneWidget);

        // A route that covers without taking focus: the trigger stays inside.
        navigator(tester).push(
          MaterialPageRoute<void>(
            requestFocus: false,
            builder: (_) => const Scaffold(body: Text('page')),
          ),
        );
        await tester.pumpAndSettle();
        expect(node.hasFocus, isTrue);
        expect(tipInTree(), isFalse);
        expect(log, ['show', 'hide']);

        navigator(tester).pop();
        await tester.pumpAndSettle();
        expect(node.hasFocus, isTrue);
        expect(tip, findsOneWidget);
        expect(log, ['show', 'hide', 'show']);
      });
    }
  });

  testWidgets('a re-derive while covered does not leave it stuck closed '
      'once its route is current', (tester) async {
    final log = <String>[];
    final node = FocusNode();
    addTearDown(node.dispose);
    final hover = ValueNotifier(true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: hover,
              builder: (_, on, _) => JustTooltip(
                enableFocus: true,
                enableHover: on,
                onShow: () => log.add('show'),
                onHide: () => log.add('hide'),
                tooltipBuilder: (_) =>
                    const SizedBox(key: Key('tip'), width: 100, height: 40),
                child: TextButton(
                  focusNode: node,
                  onPressed: () {},
                  child: const Text('btn'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);

    navigator(tester).push(
      MaterialPageRoute<void>(
        requestFocus: false,
        builder: (_) => const Scaffold(body: Text('page')),
      ),
    );
    await tester.pumpAndSettle();
    expect(tipInTree(), isFalse);

    // A configuration change re-derives show intent while covered.
    hover.value = false;
    await tester.pumpAndSettle();
    expect(node.hasFocus, isTrue);
    expect(tipInTree(), isFalse);

    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);
    expect(log, ['show', 'hide', 'show']);
  });

  testWidgets('its own route popping leaves it to the route\'s removal, with '
      'no onHide', (tester) async {
    final log = <String>[];
    final controller = JustTooltipController();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Text('home'))));
    navigator(tester).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: Center(
            child: JustTooltip(
              controller: controller,
              onShow: () => log.add('show'),
              onHide: () => log.add('hide'),
              tooltipBuilder: (_) =>
                  const SizedBox(key: Key('tip'), width: 100, height: 40),
              child: const SizedBox(key: Key('label'), width: 60, height: 30),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.show();
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);

    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(tipInTree(), isFalse);
    expect(log, ['show']);
  });

  group('hideWhenCovered: false', () {
    testWidgets('a dialog leaves it shown, as before', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        rowApp(log: log, route: dialogRoute, hideWhenCovered: false),
      );

      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(find.text('dialog'), findsOneWidget);
      expect(tipInTree(), isTrue);

      navigator(tester).pop();
      await tester.pumpAndSettle();
      expect(tip, findsOneWidget);
      expect(log, ['show']);
    });

    testWidgets('controller.show() under a dialog shows it, as before', (
      tester,
    ) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        rowApp(
          log: log,
          route: pageRoute,
          controller: controller,
          tap: TooltipTap.none,
          hideWhenCovered: false,
        ),
      );
      navigator(tester).push(dialogRoute(home(tester)));
      await tester.pumpAndSettle();

      controller.show();
      await tester.pumpAndSettle();
      expect(tipInTree(), isTrue);
      expect(log, ['show']);
    });

    testWidgets('a page and a popup menu leave it shown, as before', (
      tester,
    ) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        rowApp(
          log: log,
          route: pageRoute,
          controller: controller,
          tap: TooltipTap.none,
          hideWhenCovered: false,
        ),
      );
      controller.show();
      await tester.pumpAndSettle();

      showMenu<void>(
        context: tester.element(label),
        position: const RelativeRect.fromLTRB(10, 10, 10, 10),
        items: const [PopupMenuItem<void>(child: Text('item'))],
      );
      await tester.pumpAndSettle();
      expect(tipInTree(), isTrue);
      navigator(tester).pop();
      await tester.pumpAndSettle();

      navigator(tester).push(pageRoute(home(tester)));
      await tester.pumpAndSettle();
      expect(tipInTree(), isTrue);
      navigator(tester).pop();
      await tester.pumpAndSettle();
      expect(tip, findsOneWidget);
      expect(log, ['show']);
    });

    testWidgets('switching it to true under an opaque page ends a long fade '
        'before the pop', (tester) async {
      final log = <String>[];
      final controller = JustTooltipController();
      final hide = ValueNotifier(false);
      await tester.pumpWidget(
        ValueListenableBuilder<bool>(
          valueListenable: hide,
          builder: (_, on, _) => rowApp(
            log: log,
            route: pageRoute,
            controller: controller,
            tap: TooltipTap.none,
            hideWhenCovered: on,
            animationDuration: const Duration(seconds: 2),
          ),
        ),
      );
      controller.show();
      await tester.pumpAndSettle();
      navigator(tester).push(pageRoute(home(tester)));
      await tester.pumpAndSettle();
      expect(log, ['show']);

      hide.value = true;
      await tester.pumpAndSettle();
      expect(find.text('page'), findsOneWidget);
      expect(log, ['show', 'hide']);
    });

    testWidgets('switching it to true while covered hides the tooltip', (
      tester,
    ) async {
      final log = <String>[];
      final hide = ValueNotifier(false);
      await tester.pumpWidget(
        ValueListenableBuilder<bool>(
          valueListenable: hide,
          builder: (_, on, _) =>
              rowApp(log: log, route: dialogRoute, hideWhenCovered: on),
        ),
      );
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(tipInTree(), isTrue);

      hide.value = true;
      await tester.pumpAndSettle();
      expect(tipInTree(), isFalse);
      expect(log, ['show', 'hide']);
    });
  });

  testWidgets('a tooltip with no route around it is never covered', (
    tester,
  ) async {
    final log = <String>[];
    final controller = JustTooltipController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => Center(
                child: JustTooltip(
                  controller: controller,
                  onShow: () => log.add('show'),
                  onHide: () => log.add('hide'),
                  tooltipBuilder: (_) =>
                      const SizedBox(key: Key('tip'), width: 100, height: 40),
                  child: const SizedBox(
                    key: Key('label'),
                    width: 60,
                    height: 30,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    controller.show();
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);

    controller.hide();
    await tester.pumpAndSettle();
    expect(tip, findsNothing);
    expect(log, ['show', 'hide']);
  });
}

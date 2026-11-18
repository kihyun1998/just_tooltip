import 'package:flutter/gestures.dart';
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

  group('hideWhenCovered: false, a hide under an opaque page', () {
    /// A message tooltip with a 2 s fade that stays shown under a covering
    /// route.
    Widget mutedApp({
      required List<String> log,
      required JustTooltipController controller,
      required TooltipRegistry registry,
      ValueNotifier<String>? message,
      Duration? showDuration,
    }) {
      final text = message ?? ValueNotifier('tip');
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: text,
              builder: (_, m, _) => JustTooltip(
                controller: controller,
                registry: registry,
                message: m,
                hideWhenCovered: false,
                showDuration: showDuration,
                animationDuration: const Duration(seconds: 2),
                onShow: () => log.add('show'),
                onHide: () {
                  log.add('hide');
                  phases.add(SchedulerBinding.instance.schedulerPhase);
                },
                child: const SizedBox(key: Key('label'), width: 60, height: 30),
              ),
            ),
          ),
        ),
      );
    }

    /// Shows the tooltip, pushes an opaque page, and waits until the page
    /// has come in and stopped the route below's tickers.
    Future<void> showThenCover(
      WidgetTester tester, {
      Widget page = const Scaffold(body: Text('page')),
    }) async {
      await tester.pumpAndSettle();
      navigator(tester).push(MaterialPageRoute<void>(builder: (_) => page));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('page'), findsOneWidget);
    }

    /// Asserts that the hide ended within two frames, with the page still on
    /// top.
    Future<void> expectEndedUnderPage(
      WidgetTester tester,
      List<String> log,
    ) async {
      await tester.pump();
      await tester.pump();
      expect(log, ['show', 'hide']);
      expect(phases, isNot(contains(SchedulerPhase.persistentCallbacks)));
      expect(find.text('page'), findsOneWidget);
      expect(navigator(tester).canPop(), isTrue);
    }

    testWidgets('controller.hide() calls onHide before the pop', (
      tester,
    ) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        mutedApp(log: log, controller: controller, registry: TooltipRegistry()),
      );
      controller.show();
      await showThenCover(tester);

      controller.hide();
      await expectEndedUnderPage(tester, log);
    });

    testWidgets('the showDuration auto-hide calls onHide before the pop', (
      tester,
    ) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        mutedApp(
          log: log,
          controller: controller,
          registry: TooltipRegistry(),
          showDuration: const Duration(seconds: 4),
        ),
      );
      controller.show();
      await showThenCover(tester);
      expect(log, ['show']);

      await tester.pump(const Duration(seconds: 4));
      await expectEndedUnderPage(tester, log);
    });

    testWidgets('a dismissal by another tooltip\'s show on the page calls '
        'onHide before the pop', (tester) async {
      final log = <String>[];
      final controller = JustTooltipController();
      final other = JustTooltipController();
      final registry = TooltipRegistry();
      await tester.pumpWidget(
        mutedApp(log: log, controller: controller, registry: registry),
      );
      controller.show();
      await showThenCover(
        tester,
        page: Scaffold(
          body: Column(
            children: [
              const Text('page'),
              JustTooltip(
                controller: other,
                registry: registry,
                message: 'other',
                animationDuration: Duration.zero,
                child: const SizedBox(width: 60, height: 30),
              ),
            ],
          ),
        ),
      );

      other.show();
      await expectEndedUnderPage(tester, log);
    });

    testWidgets('Escape calls onHide before the pop', (tester) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        mutedApp(log: log, controller: controller, registry: TooltipRegistry()),
      );
      controller.show();
      await showThenCover(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await expectEndedUnderPage(tester, log);
    });

    testWidgets('losing its content calls onHide before the pop', (
      tester,
    ) async {
      final log = <String>[];
      final controller = JustTooltipController();
      final message = ValueNotifier('tip');
      await tester.pumpWidget(
        mutedApp(
          log: log,
          controller: controller,
          registry: TooltipRegistry(),
          message: message,
        ),
      );
      controller.show();
      await showThenCover(tester);

      message.value = '';
      await expectEndedUnderPage(tester, log);
    });

    testWidgets('a fade begun before the push ends once the page stops it', (
      tester,
    ) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        mutedApp(log: log, controller: controller, registry: TooltipRegistry()),
      );
      controller.show();
      await tester.pumpAndSettle();

      controller.hide();
      await tester.pump();
      navigator(tester).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('page')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await expectEndedUnderPage(tester, log);
    });

    testWidgets('under a dialog, which leaves the tickers running, a hide '
        'still fades for the whole duration', (tester) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        mutedApp(log: log, controller: controller, registry: TooltipRegistry()),
      );
      controller.show();
      await tester.pumpAndSettle();
      navigator(tester).push(dialogRoute(home(tester)));
      await tester.pumpAndSettle();

      controller.hide();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1900));
      expect(log, ['show']);
      await tester.pump(const Duration(milliseconds: 200));
      expect(log, ['show', 'hide']);
    });

    testWidgets('on its own page a hide still fades for the whole duration', (
      tester,
    ) async {
      final log = <String>[];
      final controller = JustTooltipController();
      await tester.pumpWidget(
        mutedApp(log: log, controller: controller, registry: TooltipRegistry()),
      );
      controller.show();
      await tester.pumpAndSettle();

      controller.hide();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1900));
      expect(log, ['show']);
      await tester.pump(const Duration(milliseconds: 200));
      expect(log, ['show', 'hide']);
    });
  });

  testWidgets('a hide under a TickerMode that disables it calls onHide at '
      'once', (tester) async {
    final log = <String>[];
    final controller = JustTooltipController();
    final enabled = ValueNotifier(true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder: (_, on, child) => TickerMode(enabled: on, child: child!),
              child: JustTooltip(
                controller: controller,
                message: 'tip',
                animationDuration: const Duration(seconds: 2),
                onShow: () => log.add('show'),
                onHide: () => log.add('hide'),
                child: const SizedBox(width: 60, height: 30),
              ),
            ),
          ),
        ),
      ),
    );
    controller.show();
    await tester.pumpAndSettle();
    enabled.value = false;
    await tester.pump();

    controller.hide();
    await tester.pump();
    expect(log, ['show', 'hide']);
  });

  testWidgets('a tooltip moved by a GlobalKey mid-fade, its tickers stopped '
      'later, shows on a hover and hides when the pointer leaves', (
    tester,
  ) async {
    final controller = JustTooltipController();
    final key = GlobalKey();
    final left = ValueNotifier(true);
    final tickers = ValueNotifier(true);
    Widget tooltip() => JustTooltip(
      key: key,
      controller: controller,
      message: 'tip',
      waitDuration: const Duration(milliseconds: 500),
      animationDuration: const Duration(seconds: 2),
      child: const SizedBox(key: Key('label'), width: 60, height: 30),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: tickers,
              builder: (_, on, child) => TickerMode(enabled: on, child: child!),
              child: ValueListenableBuilder<bool>(
                valueListenable: left,
                builder: (_, l, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 100, child: l ? tooltip() : null),
                    SizedBox(width: 100, child: l ? null : tooltip()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    controller.show();
    await tester.pumpAndSettle();
    controller.hide();
    await tester.pump(const Duration(milliseconds: 100));
    left.value = false;
    await tester.pump();
    expect(controller.isShowing, isFalse);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('label'))));
    await tester.pump();
    tickers.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.isShowing, isTrue);

    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(controller.isShowing, isFalse);
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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A tap trigger either claims the tap ([TooltipTap.claim]) or only watches it
/// ([TooltipTap.observe]), which decides whether a tappable ancestor still
/// receives it.
void main() {
  /// A tooltip on a label inside a tappable row, the shape of a folder-view
  /// row whose label carries a tooltip.
  Widget rowApp({
    required VoidCallback onRowTap,
    TooltipTap? tap,
    bool enableTap = false,
    TooltipAnchor anchor = TooltipAnchor.child,
    double? touchSlop,
  }) {
    return MaterialApp(
      builder: touchSlop == null
          ? null
          : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  gestureSettings: DeviceGestureSettings(touchSlop: touchSlop),
                ),
                child: child!,
              ),
      home: Scaffold(
        body: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRowTap,
            child: SizedBox(
              width: 600,
              height: 60,
              child: Align(
                child: JustTooltip(
                  tap: tap,
                  enableTap: enableTap,
                  anchor: anchor,
                  enableHover: false,
                  theme: const JustTooltipTheme(padding: EdgeInsets.zero),
                  tooltipBuilder: (context) => const SizedBox(
                    key: Key('tip'),
                    width: 100,
                    height: 40,
                  ),
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
    );
  }

  final tip = find.byKey(const Key('tip'));
  final label = find.byKey(const Key('label'));

  testWidgets('an observed tap toggles the tooltip and reaches the ancestor',
      (tester) async {
    var rowTaps = 0;
    await tester
        .pumpWidget(rowApp(tap: TooltipTap.observe, onRowTap: () => rowTaps++));

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);
    expect(rowTaps, 1, reason: 'observe does not claim the tap');

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(tip, findsNothing);
    expect(rowTaps, 2);
  });

  testWidgets('a drag past the touch slop does not toggle', (tester) async {
    var rowTaps = 0;
    await tester
        .pumpWidget(rowApp(tap: TooltipTap.observe, onRowTap: () => rowTaps++));

    final drag = await tester.startGesture(tester.getCenter(label));
    await drag.moveBy(const Offset(kTouchSlop + 10, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(tip, findsNothing);
  });

  testWidgets('a move within the touch slop still toggles', (tester) async {
    await tester.pumpWidget(rowApp(tap: TooltipTap.observe, onRowTap: () {}));

    final press = await tester.startGesture(tester.getCenter(label));
    await press.moveBy(const Offset(kTouchSlop - 8, 0));
    await press.up();
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);
  });

  testWidgets('the slop comes from the gesture settings when there are any',
      (tester) async {
    await tester.pumpWidget(rowApp(
      tap: TooltipTap.observe,
      onRowTap: () {},
      touchSlop: 4,
    ));

    final press = await tester.startGesture(tester.getCenter(label));
    await press.moveBy(const Offset(10, 0));
    await press.up();
    await tester.pumpAndSettle();
    expect(tip, findsNothing, reason: '10 px is past a 4 px slop');
  });

  testWidgets('a cancelled pointer does not toggle', (tester) async {
    await tester.pumpWidget(rowApp(tap: TooltipTap.observe, onRowTap: () {}));

    final press = await tester.startGesture(tester.getCenter(label));
    await press.cancel();
    await tester.pumpAndSettle();
    expect(tip, findsNothing);
  });

  testWidgets('a secondary-button click does not toggle', (tester) async {
    await tester.pumpWidget(rowApp(tap: TooltipTap.observe, onRowTap: () {}));

    await tester.tap(label,
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(tip, findsNothing);
  });

  testWidgets('an observed tap anchors a pointer tooltip at the tap',
      (tester) async {
    await tester.pumpWidget(rowApp(
      tap: TooltipTap.observe,
      anchor: TooltipAnchor.pointer,
      onRowTap: () {},
    ));

    final at = tester.getTopLeft(label) + const Offset(60, 20);
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(
        tester.getRect(tip).center.dx, moreOrLessEquals(at.dx, epsilon: 0.5));
  });

  /// [rowApp]'s tooltip under an arbitrary ancestor instead of a tap row.
  Widget underApp(Widget Function(Widget tooltip) ancestor) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ancestor(
            JustTooltip(
              tap: TooltipTap.observe,
              enableHover: false,
              tooltipBuilder: (context) =>
                  const SizedBox(key: Key('tip'), width: 100, height: 40),
              child: const ColoredBox(
                color: Color(0xFF000000),
                child: SizedBox(key: Key('label'), width: 400, height: 40),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('an ancestor long press that wins leaves the tooltip shut',
      (tester) async {
    final log = <String>[];
    await tester.pumpWidget(underApp((c) => GestureDetector(
          onLongPress: () => log.add('long press'),
          onTap: () => log.add('tap'),
          child: c,
        )));

    await tester.longPress(label);
    await tester.pumpAndSettle();
    expect(log, ['long press']);
    expect(tip, findsNothing);
  });

  testWidgets('a short tap under a long-press-only ancestor still toggles',
      (tester) async {
    await tester.pumpWidget(
        underApp((c) => GestureDetector(onLongPress: () {}, child: c)));

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);
  });

  testWidgets('a mouse drag an ancestor pans with leaves the tooltip shut',
      (tester) async {
    final log = <String>[];
    await tester.pumpWidget(underApp((c) => GestureDetector(
          onPanStart: (_) => log.add('pan'),
          onTap: () => log.add('tap'),
          child: c,
        )));

    // Past a mouse's 2 px pan slop, inside the 18 px touch slop.
    final drag = await tester.startGesture(tester.getCenter(label),
        kind: PointerDeviceKind.mouse);
    await drag.moveBy(const Offset(10, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(log, ['pan']);
    expect(tip, findsNothing);
  });

  testWidgets('a press whose buttons change before release does not toggle',
      (tester) async {
    await tester.pumpWidget(rowApp(tap: TooltipTap.observe, onRowTap: () {}));

    final at = tester.getCenter(label);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.down(at));
    await tester.sendEventToBinding(mouse.move(at + const Offset(1, 0),
        buttons: kPrimaryMouseButton | kSecondaryMouseButton));
    await tester.sendEventToBinding(mouse.up());
    await tester.pumpAndSettle();
    expect(tip, findsNothing);
  });

  // A known hole, pinned so a fix shows up as a failure here: the first tap
  // is released while the double tap is still undecided.
  testWidgets('an ancestor double tap fires and the tooltip flickers once',
      (tester) async {
    final log = <String>[];
    var shows = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: GestureDetector(
            onDoubleTap: () => log.add('double tap'),
            child: JustTooltip(
              tap: TooltipTap.observe,
              enableHover: false,
              onShow: () => shows++,
              tooltipBuilder: (context) =>
                  const SizedBox(key: Key('tip'), width: 100, height: 40),
              child: const ColoredBox(
                color: Color(0xFF000000),
                child: SizedBox(key: Key('label'), width: 400, height: 40),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(label);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(log, ['double tap']);
    expect(shows, 1, reason: 'the first tap opened it');
    expect(tip, findsNothing, reason: 'the second tap closed it');
  });

  testWidgets('changing tap while shown takes effect on the next tap',
      (tester) async {
    var rowTaps = 0;
    await tester
        .pumpWidget(rowApp(tap: TooltipTap.claim, onRowTap: () => rowTaps++));
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);
    expect(rowTaps, 0);

    await tester
        .pumpWidget(rowApp(tap: TooltipTap.observe, onRowTap: () => rowTaps++));
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget, reason: 'a config change does not hide it');

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(tip, findsNothing);
    expect(rowTaps, 1);
  });

  testWidgets('a second finger does not move a pointer anchor', (tester) async {
    await tester.pumpWidget(rowApp(
      tap: TooltipTap.observe,
      anchor: TooltipAnchor.pointer,
      onRowTap: () {},
    ));

    final first = tester.getTopLeft(label) + const Offset(60, 20);
    final finger1 = await tester.startGesture(first, pointer: 1);
    final finger2 =
        await tester.startGesture(first + const Offset(200, 0), pointer: 2);
    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(tip).center.dx,
        moreOrLessEquals(first.dx, epsilon: 0.5));
  });

  testWidgets('a second finger is never claimed from an ancestor',
      (tester) async {
    final log = <String>[];
    await tester.pumpWidget(underApp((c) => RawGestureDetector(
          gestures: {
            _RecordingRecognizer:
                GestureRecognizerFactoryWithHandlers<_RecordingRecognizer>(
              () => _RecordingRecognizer(log),
              (_) {},
            ),
          },
          child: c,
        )));

    final at = tester.getCenter(label);
    final finger1 = await tester.startGesture(at, pointer: 1);
    final finger2 =
        await tester.startGesture(at + const Offset(40, 0), pointer: 2);
    await finger2.up();
    await finger1.up();
    await tester.pumpAndSettle();
    expect(log, contains('accept 2'));
    expect(log, isNot(contains('reject 2')));
  });

  testWidgets('a claimed tap toggles the tooltip and not the ancestor',
      (tester) async {
    var rowTaps = 0;
    await tester
        .pumpWidget(rowApp(tap: TooltipTap.claim, onRowTap: () => rowTaps++));

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);
    expect(rowTaps, 0);
  });

  testWidgets('the deprecated enableTap claims the tap', (tester) async {
    var rowTaps = 0;
    await tester.pumpWidget(rowApp(enableTap: true, onRowTap: () => rowTaps++));

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(tip, findsOneWidget);
    expect(rowTaps, 0);
  });

  testWidgets('with neither, a tap goes to the ancestor only', (tester) async {
    var rowTaps = 0;
    await tester.pumpWidget(rowApp(onRowTap: () => rowTaps++));

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(tip, findsNothing);
    expect(rowTaps, 1);
  });

  group('nested', () {
    /// An outer tooltip on a box inside a tappable row, and an inner tooltip on
    /// a child of that box.
    Widget nestedApp({
      required TooltipTap outer,
      required TooltipTap inner,
      VoidCallback? onRowTap,
      String innerMessage = 'inner',
      TooltipRegistry? innerRegistry,
      VoidCallback? onOuterShow,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: GestureDetector(
              onTap: onRowTap,
              child: JustTooltip(
                message: 'outer',
                tap: outer,
                enableHover: false,
                direction: TooltipDirection.bottom,
                onShow: onOuterShow,
                child: Container(
                  width: 300,
                  height: 100,
                  color: const Color(0xFF2196F3),
                  alignment: Alignment.center,
                  child: JustTooltip(
                    message: innerMessage,
                    tap: inner,
                    enableHover: false,
                    registry: innerRegistry,
                    child: const SizedBox(
                      key: Key('inner'),
                      width: 60,
                      height: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final innerChild = find.byKey(const Key('inner'));

    for (final outer in [TooltipTap.claim, TooltipTap.observe]) {
      for (final inner in [TooltipTap.claim, TooltipTap.observe]) {
        final rowGetsTap =
            outer == TooltipTap.observe && inner == TooltipTap.observe;
        testWidgets(
            'a tap on the inner child shows the inner tooltip '
            '(outer ${outer.name}, inner ${inner.name})', (tester) async {
          var rowTaps = 0;
          await tester.pumpWidget(nestedApp(
            outer: outer,
            inner: inner,
            onRowTap: () => rowTaps++,
          ));

          await tester.tap(innerChild);
          await tester.pumpAndSettle();

          expect(find.text('inner'), findsOneWidget);
          expect(find.text('outer'), findsNothing);
          expect(rowTaps, rowGetsTap ? 1 : 0);
        });
      }
    }

    testWidgets('the outer tooltip does not open for a tap the inner one takes',
        (tester) async {
      var outerShows = 0;
      await tester.pumpWidget(nestedApp(
        outer: TooltipTap.observe,
        inner: TooltipTap.claim,
        onOuterShow: () => outerShows++,
      ));

      await tester.tap(innerChild);
      await tester.pumpAndSettle();

      expect(outerShows, 0);
    });

    testWidgets('the inner tooltip wins across independent registries',
        (tester) async {
      await tester.pumpWidget(nestedApp(
        outer: TooltipTap.observe,
        inner: TooltipTap.observe,
        innerRegistry: TooltipRegistry(),
      ));

      await tester.tap(innerChild);
      await tester.pumpAndSettle();

      expect(find.text('inner'), findsOneWidget);
      expect(find.text('outer'), findsNothing);
    });

    testWidgets('a second tap on the inner child closes the inner tooltip',
        (tester) async {
      await tester.pumpWidget(nestedApp(
        outer: TooltipTap.observe,
        inner: TooltipTap.observe,
      ));

      await tester.tap(innerChild);
      await tester.pumpAndSettle();
      await tester.tap(innerChild);
      await tester.pumpAndSettle();

      expect(find.text('inner'), findsNothing);
      expect(find.text('outer'), findsNothing);
    });

    testWidgets(
        'an inner tooltip with nothing to show leaves the tap to the '
        'outer one', (tester) async {
      await tester.pumpWidget(nestedApp(
        outer: TooltipTap.observe,
        inner: TooltipTap.observe,
        innerMessage: '',
      ));

      await tester.tap(innerChild);
      await tester.pumpAndSettle();

      expect(find.text('outer'), findsOneWidget);
    });

    testWidgets(
        'the inner tooltip wins through an intermediate one with no tap',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: JustTooltip(
                message: 'outer',
                tap: TooltipTap.observe,
                enableHover: false,
                child: JustTooltip(
                  message: 'middle',
                  enableHover: false,
                  child: Container(
                    width: 300,
                    height: 100,
                    color: const Color(0xFF2196F3),
                    alignment: Alignment.center,
                    child: JustTooltip(
                      message: 'inner',
                      tap: TooltipTap.observe,
                      enableHover: false,
                      child: const SizedBox(
                        key: Key('inner'),
                        width: 60,
                        height: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(innerChild);
      await tester.pumpAndSettle();

      expect(find.text('inner'), findsOneWidget);
      expect(find.text('outer'), findsNothing);
    });

    testWidgets('a tap beside the inner child shows the outer tooltip',
        (tester) async {
      await tester.pumpWidget(nestedApp(
        outer: TooltipTap.observe,
        inner: TooltipTap.observe,
      ));

      await tester.tapAt(tester.getTopLeft(innerChild) - const Offset(40, 0));
      await tester.pumpAndSettle();

      expect(find.text('outer'), findsOneWidget);
      expect(find.text('inner'), findsNothing);
    });
  });

  test('tap and the deprecated enableTap together are rejected', () {
    expect(
      () => JustTooltip(
        message: 'm',
        tap: TooltipTap.observe,
        enableTap: true,
        child: const SizedBox(),
      ),
      throwsAssertionError,
    );
  });
}

/// Joins every pointer's arena and records how each one resolved for it.
class _RecordingRecognizer extends OneSequenceGestureRecognizer {
  _RecordingRecognizer(this.log);

  final List<String> log;

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) => log.add('accept $pointer');

  @override
  void rejectGesture(int pointer) => log.add('reject $pointer');

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'recording';
}

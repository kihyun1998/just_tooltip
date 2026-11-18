import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// Nesting suppression: when JustTooltips nest, the innermost tooltip under
/// the pointer is the only one that shows.
void main() {
  /// An outer 400x200 target wrapping an inner 60x30 target at its centre.
  /// A point inside the outer but outside the inner is reachable via
  /// [outerOnly], so "moved from inner to outer" is expressible.
  Widget nested({Duration? outerWait}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: JustTooltip(
            message: 'OUTER',
            waitDuration: outerWait,
            child: Container(
              key: const Key('outer'),
              width: 400,
              height: 200,
              alignment: Alignment.center,
              child: JustTooltip(
                message: 'INNER',
                child: const SizedBox(key: Key('inner'), width: 60, height: 30),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    return gesture;
  }

  Offset centreOf(WidgetTester tester, String key) =>
      tester.getCenter(find.byKey(Key(key)));

  /// A point inside the outer target but outside the inner one.
  Offset outerOnly(WidgetTester tester) {
    final rect = tester.getRect(find.byKey(const Key('outer')));
    return rect.topLeft + const Offset(20, 20);
  }

  testWidgets(
    'an ancestor waitDuration does not hijack the tooltip while the pointer '
    'rests on a nested child',
    (tester) async {
      await tester.pumpWidget(
        nested(outerWait: const Duration(milliseconds: 500)),
      );
      final gesture = await mouse(tester);

      await gesture.moveTo(centreOf(tester, 'inner'));
      await tester.pumpAndSettle();
      expect(find.text('INNER'), findsOneWidget);
      expect(find.text('OUTER'), findsNothing);

      // The outer's show timer would fire here. The pointer has not
      // moved: the innermost tooltip must still own the screen.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(
        find.text('INNER'),
        findsOneWidget,
        reason: 'the innermost tooltip stays',
      );
      expect(
        find.text('OUTER'),
        findsNothing,
        reason: 'a suppressed ancestor must never schedule a show',
      );
    },
  );

  testWidgets(
    'moving from the nested child back into the ancestor shows the ancestor, '
    'with no exit and re-enter',
    (tester) async {
      await tester.pumpWidget(nested());
      final gesture = await mouse(tester);

      await gesture.moveTo(centreOf(tester, 'inner'));
      await tester.pumpAndSettle();
      expect(find.text('INNER'), findsOneWidget);

      // The pointer never leaves the outer region, so its MouseRegion sends no
      // onEnter. Releasing the suppression is what must bring the outer back.
      await gesture.moveTo(outerOnly(tester));
      await tester.pumpAndSettle();
      expect(find.text('INNER'), findsNothing);
      expect(
        find.text('OUTER'),
        findsOneWidget,
        reason: 'released ancestor still holds the pointer',
      );
    },
  );

  testWidgets(
    'leaving the nested child and the ancestor at once shows neither',
    (tester) async {
      await tester.pumpWidget(nested());
      final gesture = await mouse(tester);

      await gesture.moveTo(centreOf(tester, 'inner'));
      await tester.pumpAndSettle();
      expect(find.text('INNER'), findsOneWidget);

      // Flutter delivers the inner onExit before the outer's. The ancestor is
      // released while it still believes it holds the pointer, and must not
      // flash into view on its way out.
      await gesture.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(
        find.text('OUTER'),
        findsNothing,
        reason: 'a release must not resurrect an ancestor that is also exiting',
      );

      await tester.pumpAndSettle();
      expect(find.text('OUTER'), findsNothing);
      expect(find.text('INNER'), findsNothing);
    },
  );

  testWidgets('suppression holds across independent registries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: JustTooltip(
              message: 'OUTER',
              child: Container(
                key: const Key('outer'),
                width: 400,
                height: 200,
                alignment: Alignment.center,
                // Its own registry: the "one tooltip at a time" policy cannot
                // dismiss the ancestor here. Only suppression can.
                child: JustTooltip(
                  message: 'INNER',
                  registry: TooltipRegistry(),
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
    final gesture = await mouse(tester);

    await gesture.moveTo(centreOf(tester, 'inner'));
    await tester.pumpAndSettle();
    expect(find.text('INNER'), findsOneWidget);
    expect(find.text('OUTER'), findsNothing);
  });

  testWidgets(
    'the innermost wins through an intermediate tooltip that has no hover '
    'region',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: JustTooltip(
                message: 'OUTER',
                // Deferring the outer's show past the registry's dismissal makes
                // a missed suppression visible: a merely-dismissed ancestor
                // comes back when its timer fires.
                waitDuration: const Duration(milliseconds: 500),
                child: Container(
                  width: 400,
                  height: 200,
                  alignment: Alignment.center,
                  // No MouseRegion of its own, so it cannot forward a
                  // suppression on the innermost's behalf.
                  child: JustTooltip(
                    message: 'MIDDLE',
                    enableHover: false,
                    child: Container(
                      width: 200,
                      height: 100,
                      alignment: Alignment.center,
                      child: JustTooltip(
                        message: 'INNER',
                        child: const SizedBox(
                          key: Key('inner'),
                          width: 40,
                          height: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await mouse(tester);

      await gesture.moveTo(centreOf(tester, 'inner'));
      await tester.pumpAndSettle();
      expect(find.text('INNER'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('INNER'), findsOneWidget);
      expect(
        find.text('OUTER'),
        findsNothing,
        reason: 'the innermost suppresses every ancestor, not just the nearest',
      );
    },
  );

  testWidgets(
    'an interactive ancestor still lets the pointer onto its tooltip',
    (tester) async {
      await tester.pumpWidget(nested());
      final gesture = await mouse(tester);

      await gesture.moveTo(outerOnly(tester));
      await tester.pumpAndSettle();
      expect(find.text('OUTER'), findsOneWidget);

      // Leaving the child starts the hover bridge; reaching the tooltip body
      // within it must cancel the hide. Nesting must not have broken this.
      await gesture.moveTo(tester.getCenter(find.text('OUTER')));
      await tester.pump(const Duration(milliseconds: 300));
      // Settle, or a tooltip that has merely *begun* its fade-out still reads as
      // present: one pump past the bridge draws the first frame of the reverse.
      await tester.pumpAndSettle();
      expect(
        find.text('OUTER'),
        findsOneWidget,
        reason: 'the pointer is on the tooltip, well past the 100ms bridge',
      );
    },
  );

  /// The inner tooltip's message is driven from outside, so it can change
  /// while the pointer already rests on the inner target — no second onEnter.
  Widget swappable(
    ValueNotifier<String> message, {
    bool hideOnEmptyMessage = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: JustTooltip(
            message: 'OUTER',
            child: Container(
              key: const Key('outer'),
              width: 400,
              height: 200,
              alignment: Alignment.center,
              child: ValueListenableBuilder<String>(
                valueListenable: message,
                builder: (context, value, _) => JustTooltip(
                  message: value,
                  hideOnEmptyMessage: hideOnEmptyMessage,
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

  testWidgets('a descendant with nothing to show suppresses nobody', (
    tester,
  ) async {
    // hideOnEmptyMessage means the inner tooltip will never draw. Claiming the
    // ancestor anyway leaves the pointer over a dead region: neither shows.
    await tester.pumpWidget(swappable(ValueNotifier('')));
    final gesture = await mouse(tester);

    await gesture.moveTo(centreOf(tester, 'inner'));
    await tester.pumpAndSettle();

    expect(
      find.text('OUTER'),
      findsOneWidget,
      reason: 'the ancestor is the innermost tooltip that can show',
    );
  });

  testWidgets(
    'content arriving under the pointer hands over to the descendant',
    (tester) async {
      final message = ValueNotifier('');
      addTearDown(message.dispose);
      await tester.pumpWidget(swappable(message));
      final gesture = await mouse(tester);

      await gesture.moveTo(centreOf(tester, 'inner'));
      await tester.pumpAndSettle();
      expect(find.text('OUTER'), findsOneWidget);

      // The pointer has not moved, so no onEnter arrives to re-derive anything.
      message.value = 'INNER';
      await tester.pumpAndSettle();

      expect(
        find.text('INNER'),
        findsOneWidget,
        reason: 'the descendant can show now, so it takes over',
      );
      expect(find.text('OUTER'), findsNothing);
    },
  );

  testWidgets('content leaving under the pointer hands back to the ancestor', (
    tester,
  ) async {
    final message = ValueNotifier('INNER');
    addTearDown(message.dispose);
    await tester.pumpWidget(swappable(message));
    final gesture = await mouse(tester);

    await gesture.moveTo(centreOf(tester, 'inner'));
    await tester.pumpAndSettle();
    expect(find.text('INNER'), findsOneWidget);
    expect(find.text('OUTER'), findsNothing);

    message.value = '';
    await tester.pumpAndSettle();

    expect(
      find.text('INNER'),
      findsNothing,
      reason: 'a tooltip with no content must not keep the screen',
    );
    expect(find.text('OUTER'), findsOneWidget);
  });

  testWidgets('hideOnEmptyMessage: false keeps an empty descendant in charge', (
    tester,
  ) async {
    // The empty bubble was asked for. It draws, so it suppresses like any other.
    await tester.pumpWidget(
      swappable(ValueNotifier(''), hideOnEmptyMessage: false),
    );
    final gesture = await mouse(tester);

    await gesture.moveTo(centreOf(tester, 'inner'));
    await tester.pumpAndSettle();

    expect(
      find.text('OUTER'),
      findsNothing,
      reason: 'a descendant that draws still wins, empty or not',
    );
  });

  testWidgets(
    'moving a suppressing descendant elsewhere releases the ancestor',
    (tester) async {
      final innerKey = GlobalKey();
      Widget app({required bool underA}) {
        Widget target(String key, bool withInner) => Container(
          key: Key(key),
          width: 400,
          height: 100,
          alignment: Alignment.center,
          child: withInner
              ? JustTooltip(
                  key: innerKey,
                  message: 'INNER',
                  child: const SizedBox(
                    key: Key('inner'),
                    width: 60,
                    height: 30,
                  ),
                )
              : const SizedBox(width: 60, height: 30),
        );
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  JustTooltip(message: 'A', child: target('a', underA)),
                  JustTooltip(message: 'B', child: target('b', !underA)),
                ],
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(app(underA: true));
      final gesture = await mouse(tester);
      await gesture.moveTo(centreOf(tester, 'inner'));
      await tester.pumpAndSettle();
      expect(find.text('INNER'), findsOneWidget);
      expect(find.text('A'), findsNothing);

      // The suppressor moves under B, keeping its state. A still has the
      // pointer and never receives another onEnter.
      await tester.pumpWidget(app(underA: false));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
    },
  );

  group(
    'a nested tooltip whose enableHover changes under a resting pointer',
    () {
      /// [nested] with the inner tooltip's enableHover following [innerHover].
      Future<void> pumpHoverable(
        WidgetTester tester,
        ValueNotifier<bool> innerHover,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: JustTooltip(
                  message: 'OUTER',
                  child: Container(
                    key: const Key('outer'),
                    width: 400,
                    height: 200,
                    alignment: Alignment.center,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: innerHover,
                      builder: (_, on, _) => JustTooltip(
                        message: 'INNER',
                        enableHover: on,
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
        final gesture = await mouse(tester);
        await gesture.moveTo(centreOf(tester, 'inner'));
        await tester.pumpAndSettle();
        expect(find.text('INNER'), findsOneWidget);
        expect(find.text('OUTER'), findsNothing);
      }

      /// Lets the hover bridge, a timer pumpAndSettle can outrun, run out.
      Future<void> settle(WidgetTester tester) async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      }

      testWidgets('turned off, it releases the ancestor', (tester) async {
        final innerHover = ValueNotifier(true);
        addTearDown(innerHover.dispose);
        await pumpHoverable(tester, innerHover);

        innerHover.value = false;
        await settle(tester);
        expect(find.text('INNER'), findsNothing);
        expect(find.text('OUTER'), findsOneWidget);
      });

      testWidgets('turned off and on again, it suppresses the ancestor again', (
        tester,
      ) async {
        final innerHover = ValueNotifier(true);
        addTearDown(innerHover.dispose);
        await pumpHoverable(tester, innerHover);

        innerHover.value = false;
        await tester.pump();
        innerHover.value = true;
        await settle(tester);
        expect(find.text('INNER'), findsOneWidget);
        expect(find.text('OUTER'), findsNothing);
      });
    },
  );

  testWidgets('removing a suppressing descendant releases the ancestor', (
    tester,
  ) async {
    Widget app({required bool withInner}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: JustTooltip(
              message: 'OUTER',
              child: Container(
                key: const Key('outer'),
                width: 400,
                height: 200,
                alignment: Alignment.center,
                child: withInner
                    ? JustTooltip(
                        message: 'INNER',
                        child: const SizedBox(
                          key: Key('inner'),
                          width: 60,
                          height: 30,
                        ),
                      )
                    : const SizedBox(width: 60, height: 30),
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(app(withInner: true));
    final gesture = await mouse(tester);
    await gesture.moveTo(centreOf(tester, 'inner'));
    await tester.pumpAndSettle();
    expect(find.text('INNER'), findsOneWidget);
    expect(find.text('OUTER'), findsNothing);

    // The suppressor leaves the tree. It must drop its hold on the ancestor,
    // which still has the pointer and never receives another onEnter.
    await tester.pumpWidget(app(withInner: false));
    await tester.pumpAndSettle();
    expect(find.text('INNER'), findsNothing);
    expect(
      find.text('OUTER'),
      findsOneWidget,
      reason: 'a disposed descendant must not suppress forever',
    );
  });

  /// The pointer resting on a tooltip's body, entered with hover on, counts as
  /// the pointer, and the pointer wins over a focus suppressor: the tooltip
  /// stays shown when keyboard focus reaches a tooltip nested in its child. Outer A
  /// and nested D each have a registry of their own, so only suppression could
  /// hide A.
  group('a tooltip the body holds, and a nested tooltip focused', () {
    Widget app({
      required FocusNode dNode,
      required List<String> log,
      bool aFocus = false,
      bool aHover = true,
      TooltipRegistry? sharedRegistry,
      FocusNode? aNode,
      FocusNode? awayNode,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 60),
                JustTooltip(
                  message: 'A',
                  registry: sharedRegistry ?? TooltipRegistry(),
                  enableFocus: aFocus,
                  enableHover: aHover,
                  direction: TooltipDirection.top,
                  onShow: () => log.add('show A'),
                  onHide: () => log.add('hide A'),
                  child: SizedBox(
                    key: const Key('a'),
                    width: 300,
                    height: 100,
                    child: Stack(
                      children: [
                        if (aNode != null)
                          Align(
                            alignment: Alignment.topLeft,
                            child: TextButton(
                              focusNode: aNode,
                              onPressed: () {},
                              child: const Text('a'),
                            ),
                          ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: JustTooltip(
                            message: 'D',
                            registry: sharedRegistry ?? TooltipRegistry(),
                            enableFocus: true,
                            direction: TooltipDirection.bottom,
                            onShow: () => log.add('show D'),
                            onHide: () => log.add('hide D'),
                            child: TextButton(
                              focusNode: dNode,
                              onPressed: () {},
                              child: const Text('d'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (awayNode != null)
                  TextButton(
                    focusNode: awayNode,
                    onPressed: () {},
                    child: const Text('away'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('a hover-shown tooltip with the pointer on its body stays '
        'shown', (tester) async {
      final dNode = FocusNode();
      addTearDown(dNode.dispose);
      final log = <String>[];
      await tester.pumpWidget(app(dNode: dNode, log: log));
      final gesture = await mouse(tester);

      await gesture.moveTo(
        tester.getTopLeft(find.byKey(const Key('a'))) + const Offset(10, 10),
      );
      await tester.pumpAndSettle();
      await gesture.moveTo(tester.getCenter(find.text('A')));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget, reason: 'the body holds A');
      expect(log, ['show A']);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(dNode.hasPrimaryFocus, isTrue, reason: 'focus reached D by a key');
      expect(find.text('D'), findsOneWidget);
      expect(
        find.text('A'),
        findsOneWidget,
        reason: 'the pointer on the body wins over the focus suppressor',
      );
      expect(log, ['show A', 'show D']);

      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'the body let A go');
      expect(log, ['show A', 'show D', 'hide A']);
    });

    testWidgets('a focus-shown tooltip the body holds after focus left stays '
        'shown', (tester) async {
      final aNode = FocusNode();
      final dNode = FocusNode();
      final awayNode = FocusNode();
      addTearDown(aNode.dispose);
      addTearDown(dNode.dispose);
      addTearDown(awayNode.dispose);
      final log = <String>[];
      await tester.pumpWidget(
        app(
          dNode: dNode,
          log: log,
          aFocus: true,
          aNode: aNode,
          awayNode: awayNode,
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(aNode.hasPrimaryFocus, isTrue);
      expect(log, ['show A']);
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.text('A')));
      await tester.pumpAndSettle();

      awayNode.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget, reason: 'the body holds A');
      expect(log, ['show A']);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(dNode.hasPrimaryFocus, isTrue, reason: 'focus reached D by a key');
      expect(find.text('D'), findsOneWidget);
      expect(
        find.text('A'),
        findsOneWidget,
        reason: 'the pointer on the body wins over the focus suppressor',
      );
      expect(log, ['show A', 'show D']);
    });

    testWidgets('a tooltip keyboard focus holds, with the pointer on its body, '
        'stays shown when focus moves straight onto the nested tooltip', (
      tester,
    ) async {
      final aNode = FocusNode();
      final dNode = FocusNode();
      addTearDown(aNode.dispose);
      addTearDown(dNode.dispose);
      final log = <String>[];
      await tester.pumpWidget(
        app(dNode: dNode, log: log, aFocus: true, aNode: aNode),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(aNode.hasPrimaryFocus, isTrue);
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.text('A')));
      await tester.pumpAndSettle();
      expect(log, ['show A']);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(dNode.hasPrimaryFocus, isTrue, reason: 'focus reached D by a key');
      expect(find.text('D'), findsOneWidget);
      expect(
        find.text('A'),
        findsOneWidget,
        reason: 'the pointer on the body wins over the focus suppressor',
      );
      expect(log, ['show A', 'show D']);

      // Leaving the body lets D's focus suppress A; focus back on A's own
      // button shows it again.
      await gesture.moveTo(Offset.zero);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(log, [
        'show A',
        'show D',
        'hide A',
      ], reason: 'hidden at once, not after the 100ms bridge');
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: "D's focus suppresses A");
      expect(log, ['show A', 'show D', 'hide A']);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(aNode.hasPrimaryFocus, isTrue);
      expect(find.text('A'), findsOneWidget, reason: 'focus is back on A');
      expect(log, ['show A', 'show D', 'hide A', 'show A', 'hide D']);
    });

    testWidgets('a tooltip keyboard focus holds stays shown when the pointer '
        'moves back from its body onto its child, a nested tooltip focused', (
      tester,
    ) async {
      final aNode = FocusNode();
      final dNode = FocusNode();
      addTearDown(aNode.dispose);
      addTearDown(dNode.dispose);
      final log = <String>[];
      await tester.pumpWidget(
        app(dNode: dNode, log: log, aFocus: true, aNode: aNode),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.text('A')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(dNode.hasPrimaryFocus, isTrue);
      expect(log, ['show A', 'show D']);

      await gesture.moveTo(tester.getCenter(find.byKey(const Key('a'))));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        find.text('A'),
        findsOneWidget,
        reason: 'the pointer is inside the child, which wins over D',
      );
      expect(log, ['show A', 'show D']);
    });

    testWidgets('in one registry, focus back from the nested tooltip during '
        "the outer tooltip's eviction fade turns the fade back", (
      tester,
    ) async {
      final aNode = FocusNode();
      final dNode = FocusNode();
      addTearDown(aNode.dispose);
      addTearDown(dNode.dispose);
      final log = <String>[];
      await tester.pumpWidget(
        app(
          dNode: dNode,
          log: log,
          aFocus: true,
          aNode: aNode,
          sharedRegistry: TooltipRegistry(),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.text('A')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(const Duration(milliseconds: 20));
      expect(dNode.hasPrimaryFocus, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(aNode.hasPrimaryFocus, isTrue);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.text('A'), findsOneWidget, reason: 'frame $i');
      }
      await tester.pumpAndSettle();
      expect(log, isNot(contains('hide A')));
    });

    testWidgets('a body entered with enableHover off does not win over the '
        'focus suppressor', (tester) async {
      final aNode = FocusNode();
      final dNode = FocusNode();
      addTearDown(aNode.dispose);
      addTearDown(dNode.dispose);
      final log = <String>[];
      await tester.pumpWidget(
        app(dNode: dNode, log: log, aFocus: true, aHover: false, aNode: aNode),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.text('A')));
      await tester.pumpAndSettle();
      expect(log, ['show A']);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(dNode.hasPrimaryFocus, isTrue);
      expect(find.text('A'), findsNothing, reason: "D's focus suppresses A");
      expect(log, ['show A', 'show D', 'hide A']);
    });

    testWidgets('a tooltip the pointer shows over a focused nested tooltip '
        'stays shown when the pointer crosses onto its body', (tester) async {
      final dNode = FocusNode();
      addTearDown(dNode.dispose);
      final log = <String>[];
      await tester.pumpWidget(app(dNode: dNode, log: log));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(dNode.hasPrimaryFocus, isTrue);
      final gesture = await mouse(tester);
      await gesture.moveTo(
        tester.getTopLeft(find.byKey(const Key('a'))) + const Offset(10, 10),
      );
      await tester.pumpAndSettle();
      expect(log, ['show D', 'show A'], reason: 'the pointer wins');

      await gesture.moveTo(tester.getCenter(find.text('A')));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget, reason: 'the body holds A');
      expect(find.text('D'), findsOneWidget);
      expect(log, ['show D', 'show A']);
    });
  });

  /// Z wraps A, and A wraps T. A, keyed by a [GlobalKey], moves out of Z to a
  /// slot outside it, carrying T: T's nearest enclosing tooltip stays A, while
  /// Z is no longer above it.
  group('a tooltip moved with its nearest enclosing tooltip', () {
    Widget app({
      required GlobalKey aKey,
      required bool aInZ,
      bool aPresent = true,
      FocusNode? zNode,
      FocusNode? tNode,
      TooltipRegistry? zRegistry,
      TooltipRegistry? tRegistry,
      JustTooltipController? bController,
    }) {
      final a = JustTooltip(
        key: aKey,
        message: 'A',
        child: Container(
          key: const Key('a'),
          width: 200,
          height: 80,
          alignment: Alignment.center,
          child: JustTooltip(
            message: 'T',
            registry: tRegistry,
            enableFocus: tNode != null,
            child: tNode != null
                ? TextButton(
                    key: const Key('t'),
                    focusNode: tNode,
                    onPressed: () {},
                    child: const Text('t'),
                  )
                : const SizedBox(key: Key('t'), width: 60, height: 30),
          ),
        ),
      );
      final slot = aPresent ? a : const SizedBox(width: 200, height: 80);
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bController != null)
                  JustTooltip(
                    message: 'B',
                    registry: zRegistry,
                    controller: bController,
                    child: const SizedBox(width: 40, height: 20),
                  ),
                JustTooltip(
                  message: 'Z',
                  registry: zRegistry,
                  enableFocus: zNode != null,
                  child: Container(
                    key: const Key('z'),
                    width: 400,
                    height: 160,
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (zNode != null)
                          TextButton(
                            focusNode: zNode,
                            onPressed: () {},
                            child: const Text('z'),
                          ),
                        aInZ ? slot : const SizedBox(width: 200, height: 80),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                aInZ ? const SizedBox(width: 200, height: 80) : slot,
              ],
            ),
          ),
        ),
      );
    }

    /// A point inside Z's target, above the slot A sits in.
    Offset zOnly(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const Key('z'))) + const Offset(20, 20);

    Future<TestGesture> suppressZWithT(
      WidgetTester tester,
      GlobalKey aKey,
    ) async {
      await tester.pumpWidget(app(aKey: aKey, aInZ: true));
      final gesture = await mouse(tester);
      await gesture.moveTo(centreOf(tester, 't'));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
      expect(find.text('Z'), findsNothing);
      return gesture;
    }

    testWidgets('releases the tooltips it leaves behind', (tester) async {
      final aKey = GlobalKey();
      final gesture = await suppressZWithT(tester, aKey);

      await tester.pumpWidget(app(aKey: aKey, aInZ: false));
      await tester.pumpAndSettle();
      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await gesture.moveTo(zOnly(tester));
      await tester.pumpAndSettle();

      expect(find.text('Z'), findsOneWidget, reason: 'T left Z behind');
    });

    testWidgets('and then removed leaves no claim on the tooltips it left', (
      tester,
    ) async {
      final aKey = GlobalKey();
      final gesture = await suppressZWithT(tester, aKey);

      await tester.pumpWidget(app(aKey: aKey, aInZ: false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(aKey: aKey, aInZ: false, aPresent: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('t')), findsNothing);
      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await gesture.moveTo(zOnly(tester));
      await tester.pumpAndSettle();

      expect(
        find.text('Z'),
        findsOneWidget,
        reason: 'a disposed T must not suppress Z',
      );
    });

    testWidgets('within the tooltip above, keeps it suppressed: it never '
        'shows', (tester) async {
      final aKey = GlobalKey();
      final log = <String>[];
      Widget build({required bool padded}) {
        final a = JustTooltip(
          key: aKey,
          message: 'A',
          child: JustTooltip(
            message: 'T',
            child: const SizedBox(key: Key('t'), width: 60, height: 30),
          ),
        );
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: JustTooltip(
                message: 'Z',
                waitDuration: Duration.zero,
                onShow: () => log.add('show Z'),
                child: Container(
                  width: 400,
                  height: 160,
                  alignment: Alignment.center,
                  child: padded
                      ? Padding(padding: EdgeInsets.zero, child: a)
                      : a,
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(build(padded: false));
      final gesture = await mouse(tester);
      await gesture.moveTo(centreOf(tester, 't'));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);

      for (final padded in [true, false]) {
        await tester.pumpWidget(build(padded: padded));
        await tester.pumpAndSettle();
      }

      expect(find.text('Z'), findsNothing);
      expect(log, isEmpty, reason: 'Z never showed across the moves');
    });

    testWidgets('releases an evicted tooltip without an act: it waits for '
        'the pointer to move onto it', (tester) async {
      // Z and B share a registry; T has one of its own, so T only suppresses
      // Z, and B still holds Z's place when A moves.
      final aKey = GlobalKey();
      final zRegistry = TooltipRegistry();
      final b = JustTooltipController();
      Widget build(bool aInZ) => app(
        aKey: aKey,
        aInZ: aInZ,
        zRegistry: zRegistry,
        tRegistry: TooltipRegistry(),
        bController: b,
      );
      await tester.pumpWidget(build(true));
      final gesture = await mouse(tester);
      await gesture.moveTo(zOnly(tester));
      await tester.pumpAndSettle();
      expect(find.text('Z'), findsOneWidget);
      b.show();
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
      expect(find.text('Z'), findsNothing, reason: 'B evicts Z');
      await gesture.moveTo(centreOf(tester, 't'));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);

      await tester.pumpWidget(build(false));
      await tester.pumpAndSettle();
      expect(
        find.text('Z'),
        findsNothing,
        reason: 'the move is not the pointer moving onto Z',
      );
      expect(find.text('B'), findsOneWidget);

      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await gesture.moveTo(zOnly(tester));
      await tester.pumpAndSettle();
      expect(find.text('Z'), findsOneWidget, reason: 'a new act shows Z');
    });

    testWidgets('releases the focus claim on the tooltips it leaves behind', (
      tester,
    ) async {
      final aKey = GlobalKey();
      final zNode = FocusNode();
      final tNode = FocusNode();
      addTearDown(zNode.dispose);
      addTearDown(tNode.dispose);
      Widget build(bool aInZ) =>
          app(aKey: aKey, aInZ: aInZ, zNode: zNode, tNode: tNode);

      await tester.pumpWidget(build(true));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(zNode.hasPrimaryFocus, isTrue);
      expect(find.text('Z'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(tNode.hasPrimaryFocus, isTrue);
      expect(find.text('T'), findsOneWidget);
      expect(find.text('Z'), findsNothing, reason: "T's focus suppresses Z");

      await tester.pumpWidget(build(false));
      await tester.pumpAndSettle();
      expect(tNode.hasPrimaryFocus, isTrue, reason: 'focus moved with T');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(zNode.hasPrimaryFocus, isTrue);
      expect(find.text('Z'), findsOneWidget, reason: 'T left Z behind');
    });
  });
}

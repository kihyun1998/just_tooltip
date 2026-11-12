import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A tooltip the registry hid for another one, while its trigger is still
/// inside, comes back only once no tooltip in its own registry holds the
/// place.
void main() {
  const fade = Duration(milliseconds: 200);

  Widget controlled({
    required JustTooltipController controller,
    required String message,
    required TooltipRegistry registry,
    required List<String> log,
    Duration animationDuration = fade,
    bool hideWhenCovered = true,
  }) {
    return JustTooltip(
      controller: controller,
      message: message,
      registry: registry,
      enableHover: false,
      hideWhenCovered: hideWhenCovered,
      animationDuration: animationDuration,
      onShow: () => log.add('$message show'),
      onHide: () => log.add('$message hide'),
      child: const SizedBox(width: 100, height: 40),
    );
  }

  /// Pumps A — shown by a pointer resting on its child — above [others], and
  /// returns once A is shown.
  Future<void> pumpHovered(
    WidgetTester tester, {
    required TooltipRegistry registry,
    required List<String> log,
    required List<Widget> others,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JustTooltip(
                  message: 'A',
                  registry: registry,
                  animationDuration: fade,
                  onShow: () => log.add('A show'),
                  onHide: () => log.add('A hide'),
                  child: const SizedBox(key: Key('a'), width: 100, height: 40),
                ),
                for (final other in others) ...[
                  const SizedBox(height: 60),
                  other,
                ],
              ],
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('a'))));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
  }

  Widget app(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
      ),
    ),
  );

  Future<TestGesture> mouseAt(WidgetTester tester, Offset position) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(position);
    await tester.pumpAndSettle();
    return mouse;
  }

  Offset centreOf(WidgetTester tester, String key) =>
      tester.getCenter(find.byKey(Key(key)));

  /// A point inside the outer target of [nestedPair] but outside the inner.
  Offset outerOnly(WidgetTester tester) =>
      tester.getRect(find.byKey(const Key('outer'))).topLeft +
      const Offset(20, 20);

  /// Tooltip A, hovered at its child [childKey], logging to [log].
  Widget hovered({
    required TooltipRegistry registry,
    required List<String> log,
    String message = 'A',
    bool enableHover = true,
    Widget child = const SizedBox(key: Key('a'), width: 100, height: 40),
  }) => JustTooltip(
    message: message,
    registry: registry,
    enableHover: enableHover,
    animationDuration: fade,
    onShow: () => log.add('A show'),
    onHide: () => log.add('A hide'),
    child: child,
  );

  /// Tooltip A wrapping a 400x200 target with tooltip N, in its own
  /// registry, at its centre; D below, in A's registry.
  Widget nestedPair({
    required TooltipRegistry registry,
    required TooltipRegistry innerRegistry,
    required JustTooltipController d,
    required List<String> log,
    String innerMessage = 'N',
    bool innerPresent = true,
  }) {
    const innerChild = SizedBox(key: Key('inner'), width: 60, height: 30);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        hovered(
          registry: registry,
          log: log,
          child: Container(
            key: const Key('outer'),
            width: 400,
            height: 200,
            alignment: Alignment.center,
            child: innerPresent
                ? JustTooltip(
                    message: innerMessage,
                    registry: innerRegistry,
                    child: innerChild,
                  )
                : innerChild,
          ),
        ),
        const SizedBox(height: 60),
        controlled(controller: d, message: 'D', registry: registry, log: log),
      ],
    );
  }

  testWidgets('stays hidden when the tooltip that took its place is itself '
      'evicted, and comes back when the last one hides', (tester) async {
    final log = <String>[];
    final registry = TooltipRegistry();
    final d = JustTooltipController();
    final b = JustTooltipController();
    await pumpHovered(
      tester,
      registry: registry,
      log: log,
      others: [
        controlled(controller: d, message: 'D', registry: registry, log: log),
        controlled(controller: b, message: 'B', registry: registry, log: log),
      ],
    );

    d.show();
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing, reason: 'D evicted A');

    b.show();
    await tester.pumpAndSettle();
    expect(find.text('D'), findsNothing, reason: 'B evicted D');
    expect(find.text('B'), findsOneWidget, reason: 'B still holds the place');
    expect(find.text('A'), findsNothing);
    expect(log, ['A show', 'D show', 'A hide', 'B show', 'D hide']);

    b.hide();
    await tester.pumpAndSettle();
    expect(find.text('B'), findsNothing);
    expect(find.text('D'), findsNothing, reason: 'no trigger inside D');
    expect(find.text('A'), findsOneWidget);
    expect(log, [
      'A show',
      'D show',
      'A hide',
      'B show',
      'D hide',
      'B hide',
      'A show',
    ]);
  });

  testWidgets('stays hidden when the tooltip that took its place is evicted '
      'with no fade', (tester) async {
    final log = <String>[];
    final registry = TooltipRegistry();
    final d = JustTooltipController();
    final b = JustTooltipController();
    await pumpHovered(
      tester,
      registry: registry,
      log: log,
      others: [
        controlled(
          controller: d,
          message: 'D',
          registry: registry,
          log: log,
          animationDuration: Duration.zero,
        ),
        controlled(controller: b, message: 'B', registry: registry, log: log),
      ],
    );

    d.show();
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing, reason: 'D evicted A');

    b.show();
    await tester.pumpAndSettle();
    expect(find.text('D'), findsNothing, reason: 'B evicted D');
    expect(find.text('B'), findsOneWidget, reason: 'B still holds the place');
    expect(find.text('A'), findsNothing);
    expect(log, ['A show', 'D show', 'A hide', 'D hide', 'B show']);
  });

  testWidgets('stays hidden when a show ends in another registry', (
    tester,
  ) async {
    final log = <String>[];
    final registry = TooltipRegistry();
    final other = TooltipRegistry();
    final b = JustTooltipController();
    final c = JustTooltipController();
    await pumpHovered(
      tester,
      registry: registry,
      log: log,
      others: [
        controlled(controller: b, message: 'B', registry: registry, log: log),
        controlled(controller: c, message: 'C', registry: other, log: log),
      ],
    );

    b.show();
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing, reason: 'B evicted A');

    c.show();
    await tester.pumpAndSettle();
    c.hide();
    await tester.pumpAndSettle();
    expect(find.text('C'), findsNothing);
    expect(find.text('B'), findsOneWidget, reason: 'B still holds the place');
    expect(find.text('A'), findsNothing);
    expect(log, ['A show', 'B show', 'A hide', 'C show', 'C hide']);

    b.hide();
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(log, [
      'A show',
      'B show',
      'A hide',
      'C show',
      'C hide',
      'B hide',
      'A show',
    ]);
  });

  group('before its revival, an evicted tooltip shows again only on a new '
      'trigger act', () {
    group('waits for its revival', () {
      testWidgets('when its content returns', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        final message = ValueNotifier('A');
        addTearDown(message.dispose);
        await tester.pumpWidget(
          app(
            ValueListenableBuilder<String>(
              valueListenable: message,
              builder: (_, m, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  hovered(registry: registry, log: log, message: m),
                  const SizedBox(height: 60),
                  controlled(
                    controller: d,
                    message: 'D',
                    registry: registry,
                    log: log,
                  ),
                ],
              ),
            ),
          ),
        );
        await mouseAt(tester, centreOf(tester, 'a'));
        expect(find.text('A'), findsOneWidget);

        d.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing, reason: 'D evicted A');

        message.value = '';
        await tester.pumpAndSettle();
        message.value = 'A';
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing);
        expect(find.text('D'), findsOneWidget, reason: 'D still holds it');
        expect(log, ['A show', 'D show', 'A hide']);

        d.hide();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        expect(log, ['A show', 'D show', 'A hide', 'D hide', 'A show']);
      });

      testWidgets('when it is moved by a GlobalKey with focus still inside', (
        tester,
      ) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final node = FocusNode();
        addTearDown(node.dispose);
        final key = GlobalKey();
        final padded = ValueNotifier(false);
        addTearDown(padded.dispose);
        await tester.pumpWidget(
          app(
            ValueListenableBuilder<bool>(
              valueListenable: padded,
              builder: (_, isPadded, _) {
                final Widget focused = JustTooltip(
                  key: key,
                  message: 'F',
                  enableFocus: true,
                  registry: registry,
                  animationDuration: fade,
                  onShow: () => log.add('F show'),
                  onHide: () => log.add('F hide'),
                  child: TextButton(
                    focusNode: node,
                    onPressed: () {},
                    child: const Text('btn'),
                  ),
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isPadded
                        ? Padding(padding: EdgeInsets.zero, child: focused)
                        : focused,
                    const SizedBox(height: 40),
                    JustTooltip(
                      message: 'H',
                      registry: registry,
                      animationDuration: fade,
                      onShow: () => log.add('H show'),
                      onHide: () => log.add('H hide'),
                      child: const SizedBox(
                        key: Key('h'),
                        width: 100,
                        height: 40,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(find.text('F'), findsOneWidget);

        final mouse = await mouseAt(tester, centreOf(tester, 'h'));
        expect(find.text('H'), findsOneWidget);
        expect(find.text('F'), findsNothing, reason: 'H evicted F');

        padded.value = true;
        await tester.pumpAndSettle();
        expect(node.hasFocus, isTrue);
        expect(find.text('F'), findsNothing);
        expect(find.text('H'), findsOneWidget, reason: 'H still holds it');
        expect(log, ['F show', 'H show', 'F hide']);

        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(find.text('H'), findsNothing);
        expect(find.text('F'), findsOneWidget);
        expect(log, ['F show', 'H show', 'F hide', 'H hide', 'F show']);
      });

      for (final (name, change) in [
        (
          'loses its content',
          (ValueNotifier<String?> inner) => inner.value = '',
        ),
        (
          'leaves the tree',
          (ValueNotifier<String?> inner) => inner.value = null,
        ),
      ]) {
        testWidgets('when a nested tooltip under the pointer $name', (
          tester,
        ) async {
          final log = <String>[];
          final registry = TooltipRegistry();
          final innerRegistry = TooltipRegistry();
          final d = JustTooltipController();
          final inner = ValueNotifier<String?>('N');
          addTearDown(inner.dispose);
          await tester.pumpWidget(
            app(
              ValueListenableBuilder<String?>(
                valueListenable: inner,
                builder: (_, m, _) => nestedPair(
                  registry: registry,
                  innerRegistry: innerRegistry,
                  d: d,
                  log: log,
                  innerMessage: m ?? '',
                  innerPresent: m != null,
                ),
              ),
            ),
          );
          final mouse = await mouseAt(tester, outerOnly(tester));
          expect(find.text('A'), findsOneWidget);

          d.show();
          await tester.pumpAndSettle();
          expect(find.text('A'), findsNothing, reason: 'D evicted A');

          await mouse.moveTo(centreOf(tester, 'inner'));
          await tester.pumpAndSettle();
          expect(find.text('N'), findsOneWidget);

          change(inner);
          await tester.pumpAndSettle();
          expect(find.text('N'), findsNothing);
          expect(find.text('A'), findsNothing);
          expect(find.text('D'), findsOneWidget, reason: 'D still holds it');
          expect(log, ['A show', 'D show', 'A hide']);

          d.hide();
          await tester.pumpAndSettle();
          expect(find.text('A'), findsOneWidget);
          expect(log, ['A show', 'D show', 'A hide', 'D hide', 'A show']);
        });
      }

      testWidgets(
        'when a nested tooltip moves out from under a still pointer',
        (tester) async {
          final log = <String>[];
          final registry = TooltipRegistry();
          final d = JustTooltipController();
          final shifted = ValueNotifier(false);
          addTearDown(shifted.dispose);
          await tester.pumpWidget(
            app(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  hovered(
                    registry: registry,
                    log: log,
                    child: Container(
                      key: const Key('outer'),
                      width: 400,
                      height: 200,
                      alignment: Alignment.center,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: shifted,
                        builder: (_, isShifted, child) => Padding(
                          padding: EdgeInsets.only(left: isShifted ? 200 : 0),
                          child: child,
                        ),
                        child: JustTooltip(
                          message: 'N',
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
                  const SizedBox(height: 60),
                  controlled(
                    controller: d,
                    message: 'D',
                    registry: registry,
                    log: log,
                  ),
                ],
              ),
            ),
          );
          final mouse = await mouseAt(tester, outerOnly(tester));
          d.show();
          await tester.pumpAndSettle();
          expect(find.text('A'), findsNothing, reason: 'D evicted A');

          await mouse.moveTo(centreOf(tester, 'inner'));
          await tester.pumpAndSettle();
          expect(find.text('N'), findsOneWidget);

          final pointer = centreOf(tester, 'inner');
          shifted.value = true;
          await tester.pumpAndSettle();
          // The exit comes after the frame and arms the hover bridge.
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(const Key('inner'))).contains(pointer),
            isFalse,
            reason: 'the nested child has left the pointer',
          );
          expect(
            tester.getRect(find.byKey(const Key('outer'))).contains(pointer),
            isTrue,
          );
          expect(find.text('N'), findsNothing);
          expect(find.text('A'), findsNothing);
          expect(find.text('D'), findsOneWidget, reason: 'D still holds it');
          expect(log, ['A show', 'D show', 'A hide']);

          d.hide();
          await tester.pumpAndSettle();
          expect(find.text('A'), findsOneWidget);
          expect(log, ['A show', 'D show', 'A hide', 'D hide', 'A show']);
        },
      );

      testWidgets('when focus moves into a nested tooltip while the pointer '
          'rests on it', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        final innerNode = FocusNode();
        addTearDown(innerNode.dispose);
        await tester.pumpWidget(
          app(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                hovered(
                  registry: registry,
                  log: log,
                  child: Container(
                    key: const Key('outer'),
                    width: 400,
                    height: 200,
                    alignment: Alignment.center,
                    child: JustTooltip(
                      message: 'N',
                      enableFocus: true,
                      registry: TooltipRegistry(),
                      child: TextButton(
                        focusNode: innerNode,
                        onPressed: () {},
                        child: const Text('inner'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                controlled(
                  controller: d,
                  message: 'D',
                  registry: registry,
                  log: log,
                ),
              ],
            ),
          ),
        );
        await mouseAt(tester, outerOnly(tester));
        d.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing, reason: 'D evicted A');

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(innerNode.hasFocus, isTrue);
        expect(find.text('N'), findsOneWidget);
        expect(find.text('A'), findsNothing);
        expect(find.text('D'), findsOneWidget, reason: 'D still holds it');
        expect(log, ['A show', 'D show', 'A hide']);
      });

      /// Tooltip A (hover and focus) holding a focusable button and nested N
      /// (hover and focus, its own registry) holding another; D below.
      Widget focusPair({
        required TooltipRegistry registry,
        required JustTooltipController d,
        required List<String> log,
        required FocusNode outerNode,
        required FocusNode innerNode,
      }) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          JustTooltip(
            message: 'A',
            registry: registry,
            enableFocus: true,
            animationDuration: fade,
            onShow: () => log.add('A show'),
            onHide: () => log.add('A hide'),
            child: Container(
              key: const Key('outer'),
              width: 400,
              height: 200,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    focusNode: outerNode,
                    onPressed: () {},
                    child: const Text('outer'),
                  ),
                  JustTooltip(
                    message: 'N',
                    enableFocus: true,
                    registry: TooltipRegistry(),
                    child: TextButton(
                      key: const Key('inner'),
                      focusNode: innerNode,
                      onPressed: () {},
                      child: const Text('inner'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 60),
          controlled(controller: d, message: 'D', registry: registry, log: log),
        ],
      );

      testWidgets('when the pointer leaves it entirely from a nested tooltip, '
          'with focus inside', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        final outerNode = FocusNode();
        final innerNode = FocusNode();
        addTearDown(outerNode.dispose);
        addTearDown(innerNode.dispose);
        await tester.pumpWidget(
          app(
            focusPair(
              registry: registry,
              d: d,
              log: log,
              outerNode: outerNode,
              innerNode: innerNode,
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(outerNode.hasFocus, isTrue);
        expect(find.text('A'), findsOneWidget);

        d.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing, reason: 'D evicted A');

        final mouse = await mouseAt(tester, centreOf(tester, 'inner'));
        expect(find.text('N'), findsOneWidget);

        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(outerNode.hasFocus, isTrue);
        expect(find.text('N'), findsNothing);
        expect(find.text('A'), findsNothing);
        expect(find.text('D'), findsOneWidget, reason: 'D still holds it');
        expect(log, ['A show', 'D show', 'A hide']);

        d.hide();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        expect(log, ['A show', 'D show', 'A hide', 'D hide', 'A show']);
      });

      testWidgets('when focus leaves a nested tooltip that was not suppressing '
          'it', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        final outerNode = FocusNode();
        final innerNode = FocusNode();
        addTearDown(outerNode.dispose);
        addTearDown(innerNode.dispose);
        await tester.pumpWidget(
          app(
            focusPair(
              registry: registry,
              d: d,
              log: log,
              outerNode: outerNode,
              innerNode: innerNode,
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(innerNode.hasFocus, isTrue);

        // The pointer on A outside N wins over N's focus.
        await mouseAt(tester, outerOnly(tester));
        expect(find.text('A'), findsOneWidget);

        d.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing, reason: 'D evicted A');

        innerNode.unfocus();
        await tester.pumpAndSettle();
        expect(innerNode.hasFocus, isFalse);
        expect(find.text('A'), findsNothing);
        expect(find.text('D'), findsOneWidget, reason: 'D still holds it');
        expect(log, ['A show', 'D show', 'A hide']);

        d.hide();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
      });

      testWidgets('when focus moves by a key off a nested tooltip that was not '
          'suppressing it, staying inside', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        final outerNode = FocusNode();
        final innerNode = FocusNode();
        addTearDown(outerNode.dispose);
        addTearDown(innerNode.dispose);
        await tester.pumpWidget(
          app(
            focusPair(
              registry: registry,
              d: d,
              log: log,
              outerNode: outerNode,
              innerNode: innerNode,
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(innerNode.hasFocus, isTrue);

        // The pointer on A outside N wins over N's focus.
        await mouseAt(tester, outerOnly(tester));
        expect(find.text('A'), findsOneWidget);

        d.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing, reason: 'D evicted A');

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(outerNode.hasFocus, isTrue);
        expect(find.text('A'), findsNothing);
        expect(find.text('D'), findsOneWidget, reason: 'D still holds it');
        expect(log, ['A show', 'D show', 'A hide']);

        d.hide();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
      });

      testWidgets('when its route is current again, with focus inside', (
        tester,
      ) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        final node = FocusNode();
        addTearDown(node.dispose);
        await tester.pumpWidget(
          app(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JustTooltip(
                  message: 'F',
                  enableFocus: true,
                  registry: registry,
                  animationDuration: fade,
                  onShow: () => log.add('F show'),
                  onHide: () => log.add('F hide'),
                  child: TextButton(
                    focusNode: node,
                    onPressed: () {},
                    child: const Text('btn'),
                  ),
                ),
                const SizedBox(height: 60),
                controlled(
                  controller: d,
                  message: 'D',
                  registry: registry,
                  log: log,
                  hideWhenCovered: false,
                ),
              ],
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(find.text('F'), findsOneWidget);

        d.show();
        await tester.pumpAndSettle();
        expect(find.text('F'), findsNothing, reason: 'D evicted F');

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute<void>(
            requestFocus: false,
            builder: (_) => const Scaffold(body: Text('page')),
          ),
        );
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
        expect(node.hasFocus, isTrue);
        expect(find.text('F'), findsNothing);
        expect(find.text('D'), findsOneWidget, reason: 'D still holds it');
        expect(log, ['F show', 'D show', 'F hide']);

        d.hide();
        await tester.pumpAndSettle();
        expect(find.text('F'), findsOneWidget);
        expect(log, ['F show', 'D show', 'F hide', 'D hide', 'F show']);
      });

      testWidgets('when its route is current again under a still pointer', (
        tester,
      ) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        await tester.pumpWidget(
          app(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                hovered(registry: registry, log: log),
                const SizedBox(height: 60),
                controlled(
                  controller: d,
                  message: 'D',
                  registry: registry,
                  log: log,
                  hideWhenCovered: false,
                ),
              ],
            ),
          ),
        );
        await mouseAt(tester, centreOf(tester, 'a'));
        expect(find.text('A'), findsOneWidget);

        d.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing, reason: 'D evicted A');

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          DialogRoute<void>(
            context: tester.element(find.byType(Scaffold)),
            builder: (_) => const AlertDialog(content: Text('dialog')),
          ),
        );
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing);
        expect(find.text('D'), findsOneWidget, reason: 'D still holds it');
        expect(log, ['A show', 'D show', 'A hide']);

        d.hide();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        expect(log, ['A show', 'D show', 'A hide', 'D hide', 'A show']);
      });

      testWidgets('when enableHover is turned on under a still pointer', (
        tester,
      ) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        final hover = ValueNotifier(true);
        addTearDown(hover.dispose);
        await tester.pumpWidget(
          app(
            ValueListenableBuilder<bool>(
              valueListenable: hover,
              builder: (_, on, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  hovered(registry: registry, log: log, enableHover: on),
                  const SizedBox(height: 60),
                  controlled(
                    controller: d,
                    message: 'D',
                    registry: registry,
                    log: log,
                  ),
                ],
              ),
            ),
          ),
        );
        await mouseAt(tester, centreOf(tester, 'a'));
        expect(find.text('A'), findsOneWidget);

        d.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing, reason: 'D evicted A');

        hover.value = false;
        await tester.pumpAndSettle();
        hover.value = true;
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing);
        expect(find.text('D'), findsOneWidget, reason: 'D still holds it');
        expect(log, ['A show', 'D show', 'A hide']);

        d.hide();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        expect(log, ['A show', 'D show', 'A hide', 'D hide', 'A show']);
      });
    });

    group('shows at once and takes the place', () {
      testWidgets('when the pointer moves back onto it from a nested tooltip', (
        tester,
      ) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        await tester.pumpWidget(
          app(
            nestedPair(
              registry: registry,
              innerRegistry: TooltipRegistry(),
              d: d,
              log: log,
            ),
          ),
        );
        final mouse = await mouseAt(tester, outerOnly(tester));
        d.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing, reason: 'D evicted A');

        await mouse.moveTo(centreOf(tester, 'inner'));
        await tester.pumpAndSettle();
        expect(find.text('N'), findsOneWidget);
        expect(find.text('A'), findsNothing);

        await mouse.moveTo(outerOnly(tester));
        await tester.pumpAndSettle();
        expect(find.text('N'), findsNothing);
        expect(find.text('A'), findsOneWidget);
        expect(find.text('D'), findsNothing);
        expect(log, ['A show', 'D show', 'A hide', 'A show', 'D hide']);
      });

      testWidgets('when focus moves back onto it from a nested tooltip by a '
          'key', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        final outerNode = FocusNode();
        final innerNode = FocusNode();
        addTearDown(outerNode.dispose);
        addTearDown(innerNode.dispose);
        await tester.pumpWidget(
          app(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JustTooltip(
                  message: 'F',
                  enableFocus: true,
                  registry: registry,
                  animationDuration: fade,
                  onShow: () => log.add('F show'),
                  onHide: () => log.add('F hide'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        focusNode: outerNode,
                        onPressed: () {},
                        child: const Text('outer'),
                      ),
                      JustTooltip(
                        message: 'N',
                        enableFocus: true,
                        registry: TooltipRegistry(),
                        child: TextButton(
                          focusNode: innerNode,
                          onPressed: () {},
                          child: const Text('inner'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                controlled(
                  controller: d,
                  message: 'D',
                  registry: registry,
                  log: log,
                ),
              ],
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(outerNode.hasFocus, isTrue);
        expect(find.text('F'), findsOneWidget);

        d.show();
        await tester.pumpAndSettle();
        expect(find.text('F'), findsNothing, reason: 'D evicted F');

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(innerNode.hasFocus, isTrue);
        expect(find.text('N'), findsOneWidget);
        expect(find.text('F'), findsNothing);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(outerNode.hasFocus, isTrue);
        expect(find.text('N'), findsNothing);
        expect(find.text('F'), findsOneWidget);
        expect(find.text('D'), findsNothing);
        expect(log, ['F show', 'D show', 'F hide', 'F show', 'D hide']);
      });

      testWidgets('when the pointer leaves its child and enters it again', (
        tester,
      ) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        await tester.pumpWidget(
          app(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                hovered(registry: registry, log: log),
                const SizedBox(height: 60),
                controlled(
                  controller: d,
                  message: 'D',
                  registry: registry,
                  log: log,
                ),
              ],
            ),
          ),
        );
        final mouse = await mouseAt(tester, centreOf(tester, 'a'));
        d.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing, reason: 'D evicted A');

        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        await mouse.moveTo(centreOf(tester, 'a'));
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        expect(find.text('D'), findsNothing);
        expect(log, ['A show', 'D show', 'A hide', 'A show', 'D hide']);
      });

      testWidgets('when the pointer enters it again, after waitDuration, '
          'through a re-derivation during the wait', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        final focusable = ValueNotifier(false);
        addTearDown(focusable.dispose);
        await tester.pumpWidget(
          app(
            ValueListenableBuilder<bool>(
              valueListenable: focusable,
              builder: (_, enableFocus, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  JustTooltip(
                    message: 'A',
                    registry: registry,
                    enableFocus: enableFocus,
                    waitDuration: const Duration(milliseconds: 300),
                    animationDuration: fade,
                    onShow: () => log.add('A show'),
                    onHide: () => log.add('A hide'),
                    child: const SizedBox(
                      key: Key('a'),
                      width: 100,
                      height: 40,
                    ),
                  ),
                  const SizedBox(height: 60),
                  controlled(
                    controller: d,
                    message: 'D',
                    registry: registry,
                    log: log,
                  ),
                ],
              ),
            ),
          ),
        );
        final mouse = await mouseAt(tester, centreOf(tester, 'a'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        d.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing, reason: 'D evicted A');

        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        await mouse.moveTo(centreOf(tester, 'a'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('A'), findsNothing, reason: 'still waiting');

        // A configuration change re-derives show intent during the wait.
        focusable.value = true;
        await tester.pump();
        expect(find.text('A'), findsNothing, reason: 'still waiting');
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        expect(find.text('D'), findsNothing);
        expect(log, ['A show', 'D show', 'A hide', 'A show', 'D hide']);
      });

      testWidgets('when keyboard focus arrives in it by a key', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        final node = FocusNode();
        final other = FocusNode();
        addTearDown(node.dispose);
        addTearDown(other.dispose);
        await tester.pumpWidget(
          app(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JustTooltip(
                  message: 'F',
                  enableFocus: true,
                  registry: registry,
                  animationDuration: fade,
                  onShow: () => log.add('F show'),
                  onHide: () => log.add('F hide'),
                  child: TextButton(
                    focusNode: node,
                    onPressed: () {},
                    child: const Text('btn'),
                  ),
                ),
                TextButton(
                  focusNode: other,
                  onPressed: () {},
                  child: const Text('other'),
                ),
                const SizedBox(height: 60),
                controlled(
                  controller: d,
                  message: 'D',
                  registry: registry,
                  log: log,
                ),
              ],
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(find.text('F'), findsOneWidget);

        d.show();
        await tester.pumpAndSettle();
        expect(find.text('F'), findsNothing, reason: 'D evicted F');

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(other.hasFocus, isTrue);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(node.hasFocus, isTrue);
        expect(find.text('F'), findsOneWidget);
        expect(find.text('D'), findsNothing);
        expect(log, ['F show', 'D show', 'F hide', 'F show', 'D hide']);
      });

      testWidgets('when its child is tapped', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        await tester.pumpWidget(
          app(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JustTooltip(
                  message: 'A',
                  registry: registry,
                  tap: TooltipTap.claim,
                  enableHover: false,
                  animationDuration: fade,
                  onShow: () => log.add('A show'),
                  onHide: () => log.add('A hide'),
                  child: const SizedBox(key: Key('a'), width: 100, height: 40),
                ),
                const SizedBox(height: 60),
                controlled(
                  controller: d,
                  message: 'D',
                  registry: registry,
                  log: log,
                ),
              ],
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('a')));
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);

        d.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing, reason: 'D evicted A');

        await tester.tap(find.byKey(const Key('a')));
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        expect(find.text('D'), findsNothing);
        expect(log, ['A show', 'D show', 'A hide', 'A show', 'D hide']);
      });

      testWidgets('when its controller shows it', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final a = JustTooltipController();
        final d = JustTooltipController();
        await tester.pumpWidget(
          app(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JustTooltip(
                  message: 'A',
                  controller: a,
                  registry: registry,
                  animationDuration: fade,
                  onShow: () => log.add('A show'),
                  onHide: () => log.add('A hide'),
                  child: const SizedBox(key: Key('a'), width: 100, height: 40),
                ),
                const SizedBox(height: 60),
                controlled(
                  controller: d,
                  message: 'D',
                  registry: registry,
                  log: log,
                ),
              ],
            ),
          ),
        );
        await mouseAt(tester, centreOf(tester, 'a'));
        expect(find.text('A'), findsOneWidget);

        d.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing, reason: 'D evicted A');

        a.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        expect(find.text('D'), findsNothing);
        expect(log, ['A show', 'D show', 'A hide', 'A show', 'D hide']);
      });
    });
  });

  group('a tooltip closed by something other than its trigger leaving, and '
      'evicted during its closing fade,', () {
    Future<void> stepFor(WidgetTester tester, Duration duration) async {
      for (var t = Duration.zero; t < duration; t += _step) {
        await tester.pump(_step);
      }
    }

    /// Hover-shown tooltip A with [showDuration], [tap] or [controller], and
    /// D below it in A's registry.
    Widget closable({
      required TooltipRegistry registry,
      required JustTooltipController d,
      required List<String> log,
      Duration? showDuration,
      TooltipTap? tap,
      JustTooltipController? controller,
    }) => app(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          JustTooltip(
            message: 'A',
            registry: registry,
            showDuration: showDuration,
            tap: tap,
            controller: controller,
            animationDuration: fade,
            onShow: () => log.add('A show'),
            onHide: () => log.add('A hide'),
            child: const SizedBox(key: Key('a'), width: 100, height: 40),
          ),
          const SizedBox(height: 60),
          controlled(controller: d, message: 'D', registry: registry, log: log),
        ],
      ),
    );

    /// With A's closing fade just begun, lets 60 ms of it run, has D evict A,
    /// then hides D.
    Future<void> evictMidFadeThenHideHolder(
      WidgetTester tester,
      JustTooltipController d,
      List<String> log,
    ) async {
      await stepFor(tester, const Duration(milliseconds: 60));
      expect(find.text('A'), findsOneWidget, reason: 'A is fading out');
      expect(log, ['A show']);

      d.show();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'D evicted A');
      expect(find.text('D'), findsOneWidget);

      d.hide();
      await tester.pumpAndSettle();
      expect(find.text('D'), findsNothing);
    }

    group('stays closed when the tooltip that evicted it hides', () {
      testWidgets('after its showDuration ran out', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        await tester.pumpWidget(
          closable(
            registry: registry,
            d: d,
            log: log,
            showDuration: const Duration(seconds: 1),
          ),
        );
        await mouseAt(tester, centreOf(tester, 'a'));
        expect(find.text('A'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));

        await evictMidFadeThenHideHolder(tester, d, log);
        expect(find.text('A'), findsNothing);
        expect(log, ['A show', 'D show', 'A hide', 'D hide']);
      });

      testWidgets('after a tap closed it', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final d = JustTooltipController();
        await tester.pumpWidget(
          closable(registry: registry, d: d, log: log, tap: TooltipTap.claim),
        );
        final mouse = await mouseAt(tester, centreOf(tester, 'a'));
        expect(find.text('A'), findsOneWidget);
        await mouse.down(centreOf(tester, 'a'));
        await mouse.up();
        await tester.pump();

        await evictMidFadeThenHideHolder(tester, d, log);
        expect(find.text('A'), findsNothing);
        expect(log, ['A show', 'D show', 'A hide', 'D hide']);
      });

      testWidgets('after its controller hid it', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final a = JustTooltipController();
        final d = JustTooltipController();
        await tester.pumpWidget(
          closable(registry: registry, d: d, log: log, controller: a),
        );
        await mouseAt(tester, centreOf(tester, 'a'));
        expect(find.text('A'), findsOneWidget);
        a.hide();
        await tester.pump();

        await evictMidFadeThenHideHolder(tester, d, log);
        expect(find.text('A'), findsNothing);
        expect(log, ['A show', 'D show', 'A hide', 'D hide']);
      });

      testWidgets('after a tap closed it, when the tooltip that evicted it '
          'was moved into its registry', (tester) async {
        final log = <String>[];
        final registry = TooltipRegistry();
        final e = JustTooltipController();
        final eRegistry = ValueNotifier(TooltipRegistry());
        addTearDown(eRegistry.dispose);
        await tester.pumpWidget(
          app(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JustTooltip(
                  message: 'A',
                  registry: registry,
                  tap: TooltipTap.claim,
                  animationDuration: fade,
                  onShow: () => log.add('A show'),
                  onHide: () => log.add('A hide'),
                  child: const SizedBox(key: Key('a'), width: 100, height: 40),
                ),
                const SizedBox(height: 60),
                ValueListenableBuilder<TooltipRegistry>(
                  valueListenable: eRegistry,
                  builder: (_, value, _) => controlled(
                    controller: e,
                    message: 'E',
                    registry: value,
                    log: log,
                  ),
                ),
              ],
            ),
          ),
        );
        final mouse = await mouseAt(tester, centreOf(tester, 'a'));
        e.show();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget, reason: 'E is elsewhere');
        expect(find.text('E'), findsOneWidget);
        await mouse.down(centreOf(tester, 'a'));
        await mouse.up();
        await tester.pump();
        await stepFor(tester, const Duration(milliseconds: 60));
        expect(find.text('A'), findsOneWidget, reason: 'A is fading out');

        eRegistry.value = registry;
        await tester.pumpAndSettle();
        expect(find.text('A'), findsNothing);
        expect(find.text('E'), findsOneWidget);

        e.hide();
        await tester.pumpAndSettle();
        expect(find.text('E'), findsNothing);
        expect(find.text('A'), findsNothing);
        expect(log, ['A show', 'E show', 'A hide', 'E hide']);
      });
    });

    testWidgets('shows again once its trigger leaves and returns', (
      tester,
    ) async {
      final log = <String>[];
      final registry = TooltipRegistry();
      final a = JustTooltipController();
      final d = JustTooltipController();
      await tester.pumpWidget(
        closable(registry: registry, d: d, log: log, controller: a),
      );
      final mouse = await mouseAt(tester, centreOf(tester, 'a'));
      a.hide();
      await tester.pump();
      await evictMidFadeThenHideHolder(tester, d, log);
      expect(find.text('A'), findsNothing);

      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await mouse.moveTo(centreOf(tester, 'a'));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(log, ['A show', 'D show', 'A hide', 'D hide', 'A show']);
    });
  });

  group('a tooltip its controller hides after another one evicted it', () {
    Future<TestGesture> pumpPair(
      WidgetTester tester, {
      required TooltipRegistry registry,
      required JustTooltipController a,
      required JustTooltipController d,
      required List<String> log,
      bool nested = false,
    }) async {
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              JustTooltip(
                message: 'A',
                registry: registry,
                controller: a,
                animationDuration: fade,
                onShow: () => log.add('A show'),
                onHide: () => log.add('A hide'),
                child: nested
                    ? Container(
                        key: const Key('outer'),
                        width: 400,
                        height: 200,
                        alignment: Alignment.center,
                        child: JustTooltip(
                          message: 'N',
                          registry: TooltipRegistry(),
                          child: const SizedBox(
                            key: Key('inner'),
                            width: 60,
                            height: 30,
                          ),
                        ),
                      )
                    : const SizedBox(key: Key('a'), width: 100, height: 40),
              ),
              const SizedBox(height: 60),
              controlled(
                controller: d,
                message: 'D',
                registry: registry,
                log: log,
              ),
            ],
          ),
        ),
      );
      return mouseAt(
        tester,
        nested ? outerOnly(tester) : centreOf(tester, 'a'),
      );
    }

    testWidgets('during the fade the eviction began stays closed when the '
        'tooltip that evicted it hides', (tester) async {
      final log = <String>[];
      final registry = TooltipRegistry();
      final a = JustTooltipController();
      final d = JustTooltipController();
      await pumpPair(tester, registry: registry, a: a, d: d, log: log);

      d.show();
      a.hide();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('A'), findsOneWidget, reason: 'A is fading out');
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(find.text('D'), findsOneWidget);

      d.hide();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(log, ['A show', 'D show', 'A hide', 'D hide']);
    });

    testWidgets('during the fade the eviction began, and turned back by its '
        'controller, shows again when a later eviction ends', (tester) async {
      final log = <String>[];
      final registry = TooltipRegistry();
      final a = JustTooltipController();
      final d = JustTooltipController();
      await pumpPair(tester, registry: registry, a: a, d: d, log: log);

      d.show();
      a.hide();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      a.show();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget, reason: 'the fade turned back');
      expect(find.text('D'), findsNothing, reason: 'A took the place back');

      d.show();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'D evicted A');
      d.hide();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(log, [
        'A show',
        'D show',
        'D hide',
        'D show',
        'A hide',
        'D hide',
        'A show',
      ]);
    });

    testWidgets('during a fade a nested tooltip began, before the eviction, '
        'is not a dismissal: the pointer moving back onto it shows it', (
      tester,
    ) async {
      final log = <String>[];
      final registry = TooltipRegistry();
      final a = JustTooltipController();
      final d = JustTooltipController();
      final mouse = await pumpPair(
        tester,
        registry: registry,
        a: a,
        d: d,
        log: log,
        nested: true,
      );
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('inner'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('A'), findsOneWidget, reason: 'A is fading out');

      d.show();
      a.hide();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(find.text('D'), findsOneWidget);

      await mouse.moveTo(outerOnly(tester));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('D'), findsNothing);
      expect(log, ['A show', 'D show', 'A hide', 'A show', 'D hide']);
    });

    testWidgets('after that fade has ended changes nothing: it shows again '
        'when the tooltip that evicted it hides', (tester) async {
      final log = <String>[];
      final registry = TooltipRegistry();
      final a = JustTooltipController();
      final d = JustTooltipController();
      await pumpPair(tester, registry: registry, a: a, d: d, log: log);

      d.show();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'D evicted A');
      a.hide();
      await tester.pumpAndSettle();

      d.hide();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(log, ['A show', 'D show', 'A hide', 'D hide', 'A show']);
    });
  });

  group('a tooltip evicted during a fade that was not a dismissal', () {
    testWidgets('shows again when the tooltip that evicted it hides, after a '
        'fade begun by its content going in the same frame', (tester) async {
      final log = <String>[];
      final registry = TooltipRegistry();
      final d = JustTooltipController();
      final message = ValueNotifier('A');
      addTearDown(message.dispose);
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: message,
                builder: (_, value, _) => JustTooltip(
                  message: value,
                  registry: registry,
                  animationDuration: fade,
                  onShow: () => log.add('A show'),
                  onHide: () => log.add('A hide'),
                  child: const SizedBox(key: Key('a'), width: 100, height: 40),
                ),
              ),
              const SizedBox(height: 60),
              controlled(
                controller: d,
                message: 'D',
                registry: registry,
                log: log,
              ),
            ],
          ),
        ),
      );
      await mouseAt(tester, centreOf(tester, 'a'));
      expect(find.text('A'), findsOneWidget);

      message.value = '';
      var evictedMidFade = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        evictedMidFade = !log.contains('A hide');
        d.show();
      });
      await tester.pump();
      expect(evictedMidFade, isTrue, reason: 'A was fading out');
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(find.text('D'), findsOneWidget);

      message.value = 'A';
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'D still holds the place');
      d.hide();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(log, ['A show', 'D show', 'A hide', 'D hide', 'A show']);
    });

    testWidgets('shows when its trigger returns, after a fade begun by the '
        'trigger leaving', (tester) async {
      final log = <String>[];
      final registry = TooltipRegistry();
      final d = JustTooltipController();
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              hovered(registry: registry, log: log),
              const SizedBox(height: 60),
              controlled(
                controller: d,
                message: 'D',
                registry: registry,
                log: log,
              ),
            ],
          ),
        ),
      );
      final mouse = await mouseAt(tester, centreOf(tester, 'a'));
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('A'), findsOneWidget, reason: 'A is fading out');

      d.show();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'D evicted A');
      d.hide();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'no trigger inside A');

      await mouse.moveTo(centreOf(tester, 'a'));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(log, ['A show', 'D show', 'A hide', 'D hide', 'A show']);
    });

    testWidgets('shows when the pointer moves back onto it, after a fade '
        'begun by a nested tooltip suppressing it', (tester) async {
      final log = <String>[];
      final registry = TooltipRegistry();
      final d = JustTooltipController();
      await tester.pumpWidget(
        app(
          nestedPair(
            registry: registry,
            innerRegistry: TooltipRegistry(),
            d: d,
            log: log,
          ),
        ),
      );
      final mouse = await mouseAt(tester, outerOnly(tester));
      expect(find.text('A'), findsOneWidget);
      await mouse.moveTo(centreOf(tester, 'inner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('A'), findsOneWidget, reason: 'A is fading out');

      d.show();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'D evicted A');
      expect(find.text('N'), findsOneWidget);

      await mouse.moveTo(outerOnly(tester));
      await tester.pumpAndSettle();
      expect(find.text('N'), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('D'), findsNothing);
      expect(log, ['A show', 'D show', 'A hide', 'A show', 'D hide']);
    });

    testWidgets('shows again when the tooltip that evicted it hides, after a '
        'covered fade', (tester) async {
      final log = <String>[];
      final registry = TooltipRegistry();
      final d = JustTooltipController();
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              hovered(registry: registry, log: log),
              const SizedBox(height: 60),
              controlled(
                controller: d,
                message: 'D',
                registry: registry,
                log: log,
                hideWhenCovered: false,
              ),
            ],
          ),
        ),
      );
      await mouseAt(tester, centreOf(tester, 'a'));
      expect(find.text('A'), findsOneWidget);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        DialogRoute<void>(
          context: tester.element(find.byType(Scaffold)),
          builder: (_) => const AlertDialog(content: Text('dialog')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('A'), findsOneWidget, reason: 'A is fading out');

      d.show();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing, reason: 'D evicted A');
      navigator.pop();
      await tester.pumpAndSettle();
      d.hide();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(log, ['A show', 'D show', 'A hide', 'D hide', 'A show']);
    });
  });
}

const _step = Duration(milliseconds: 20);

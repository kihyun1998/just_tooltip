import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// A screen reader hears a tooltip's text on its child's semantics node; it is
/// given no way to open the tooltip (ADR-0009).
void main() {
  Widget app(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  /// The tooltip text on the semantics node the [text] widget belongs to.
  String heardAt(WidgetTester tester, String text) =>
      tester.getSemantics(find.text(text)).getSemanticsData().tooltip;

  group('the text', () {
    testWidgets('is the message', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(const JustTooltip(message: 'Hello', child: Text('child'))),
      );
      expect(heardAt(tester, 'child'), 'Hello');
      handle.dispose();
    });

    testWidgets('is semanticsTooltip when given', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          const JustTooltip(
            message: 'Hello',
            semanticsTooltip: 'Spoken',
            child: Text('child'),
          ),
        ),
      );
      expect(heardAt(tester, 'child'), 'Spoken');
      handle.dispose();
    });

    testWidgets('of a builder tooltip comes from semanticsTooltip only', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      Widget builder({String? message, String? semanticsTooltip}) => app(
        JustTooltip(
          message: message,
          semanticsTooltip: semanticsTooltip,
          tooltipBuilder: (_) => const Text('drawn'),
          child: const Text('child'),
        ),
      );

      await tester.pumpWidget(builder());
      expect(heardAt(tester, 'child'), '');

      // The builder takes precedence over the message, so the message is
      // never drawn and is not heard either.
      await tester.pumpWidget(builder(message: 'Hidden'));
      expect(heardAt(tester, 'child'), '');

      await tester.pumpWidget(builder(semanticsTooltip: 'Spoken'));
      expect(heardAt(tester, 'child'), 'Spoken');
      handle.dispose();
    });

    testWidgets('is absent for an empty message, either way it is drawn', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(const JustTooltip(message: '', child: Text('child'))),
      );
      expect(heardAt(tester, 'child'), '');

      // The empty bubble is shown, and not heard.
      final controller = JustTooltipController();
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: '',
            hideOnEmptyMessage: false,
            controller: controller,
            child: const Text('child'),
          ),
        ),
      );
      expect(heardAt(tester, 'child'), '');
      controller.show();
      await tester.pumpAndSettle();
      expect(controller.isShowing, isTrue);
      handle.dispose();
    });

    testWidgets('is absent without content, whatever semanticsTooltip says', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = JustTooltipController();
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: '',
            semanticsTooltip: 'Spoken',
            controller: controller,
            child: const Text('child'),
          ),
        ),
      );
      expect(heardAt(tester, 'child'), '');
      controller.show();
      await tester.pumpAndSettle();
      expect(controller.isShowing, isFalse);
      handle.dispose();
    });

    testWidgets('is absent for an empty semanticsTooltip', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          const JustTooltip(
            message: 'Hello',
            semanticsTooltip: '',
            child: Text('child'),
          ),
        ),
      );
      expect(heardAt(tester, 'child'), '');
      handle.dispose();
    });

    testWidgets('is absent with excludeFromSemantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          const JustTooltip(
            message: 'Hello',
            excludeFromSemantics: true,
            child: Text('child'),
          ),
        ),
      );
      expect(heardAt(tester, 'child'), '');
      handle.dispose();
    });

    testWidgets('follows the message across rebuilds', (tester) async {
      final handle = tester.ensureSemantics();
      Widget build(String message) =>
          app(JustTooltip(message: message, child: const Text('child')));

      await tester.pumpWidget(build('One'));
      expect(heardAt(tester, 'child'), 'One');
      await tester.pumpWidget(build('Two'));
      expect(heardAt(tester, 'child'), 'Two');
      await tester.pumpWidget(build(''));
      expect(heardAt(tester, 'child'), '');
      handle.dispose();
    });
  });

  group('showing announces the text', () {
    late List<Map<Object?, Object?>> tooltipEvents;

    setUp(() {
      tooltipEvents = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            final event = message as Map<Object?, Object?>;
            if (event['type'] == 'tooltip') tooltipEvents.add(event);
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            null,
          );
    });

    List<Object?> announced() =>
        tooltipEvents.map((e) => (e['data']! as Map)['message']).toList();

    testWidgets('once, when shown by hover', (tester) async {
      await tester.pumpWidget(
        app(const JustTooltip(message: 'Hello', child: Text('child'))),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('child')));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      expect(announced(), ['Hello']);
    });

    testWidgets('once, when shown by tap', (tester) async {
      await tester.pumpWidget(
        app(
          const JustTooltip(
            message: 'Hello',
            tap: TooltipTap.claim,
            enableHover: false,
            child: Text('child'),
          ),
        ),
      );
      await tester.tap(find.text('child'));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      expect(announced(), ['Hello']);
    });

    testWidgets('once, when shown by the controller', (tester) async {
      final controller = JustTooltipController();
      await tester.pumpWidget(
        app(
          JustTooltip(
            message: 'Hello',
            semanticsTooltip: 'Spoken',
            controller: controller,
            child: const Text('child'),
          ),
        ),
      );
      controller.show();
      await tester.pumpAndSettle();
      expect(announced(), ['Spoken']);
    });

    testWidgets('not at all when it is not heard', (tester) async {
      final excluded = JustTooltipController();
      final builder = JustTooltipController();
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              JustTooltip(
                message: 'Hello',
                excludeFromSemantics: true,
                controller: excluded,
                registry: TooltipRegistry(),
                child: const Text('a'),
              ),
              JustTooltip(
                tooltipBuilder: (_) => const Text('drawn'),
                controller: builder,
                registry: TooltipRegistry(),
                child: const Text('b'),
              ),
            ],
          ),
        ),
      );
      excluded.show();
      builder.show();
      await tester.pumpAndSettle();
      expect(excluded.isShowing && builder.isShowing, isTrue);
      expect(announced(), isEmpty);
    });
  });

  group('nested, only the innermost is heard', () {
    Widget nested({
      String inner = 'Inner',
      bool innerExcluded = false,
      bool withInner = true,
    }) => app(
      JustTooltip(
        message: 'Outer',
        child: withInner
            ? JustTooltip(
                message: inner,
                excludeFromSemantics: innerExcluded,
                child: const Text('child'),
              )
            : const Text('child'),
      ),
    );

    testWidgets('where both land on one node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(nested());
      expect(heardAt(tester, 'child'), 'Inner');
      handle.dispose();
    });

    testWidgets('unless the inner one is not heard', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(nested(inner: ''));
      expect(heardAt(tester, 'child'), 'Outer');
      await tester.pumpWidget(nested(innerExcluded: true));
      expect(heardAt(tester, 'child'), 'Outer');
      handle.dispose();
    });

    testWidgets('and the outer one is heard again once the inner one stops', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(nested());
      expect(heardAt(tester, 'child'), 'Inner');
      await tester.pumpWidget(nested(inner: ''));
      expect(heardAt(tester, 'child'), 'Outer');
      await tester.pumpWidget(nested());
      expect(heardAt(tester, 'child'), 'Inner');
      await tester.pumpWidget(nested(withInner: false));
      expect(heardAt(tester, 'child'), 'Outer');
      handle.dispose();
    });

    testWidgets('through an intermediate tooltip that is not heard', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          const JustTooltip(
            message: 'Outer',
            child: JustTooltip(
              message: '',
              child: JustTooltip(message: 'Inner', child: Text('child')),
            ),
          ),
        ),
      );
      expect(heardAt(tester, 'child'), 'Inner');
      handle.dispose();
    });

    testWidgets('even where the outer text has a node of its own', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          const JustTooltip(
            message: 'Outer',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                JustTooltip(message: 'Inner', child: Text('icon')),
                Text('label'),
              ],
            ),
          ),
        ),
      );
      expect(heardAt(tester, 'icon'), 'Inner');
      expect(
        find.semantics.byPredicate((node) => node.tooltip.contains('Outer')),
        findsNothing,
      );
      handle.dispose();
    });
  });

  group('a screen-reader tap', () {
    /// A tooltip on a label, optionally inside a tappable row.
    Widget tapApp({required TooltipTap tap, VoidCallback? onRowTap}) {
      final Widget tooltip = JustTooltip(
        message: 'Hello',
        tap: tap,
        enableHover: false,
        child: const Text('label'),
      );
      return app(
        onRowTap == null
            ? tooltip
            : GestureDetector(onTap: onRowTap, child: tooltip),
      );
    }

    SemanticsNode labelNode(WidgetTester tester) =>
        tester.getSemantics(find.text('label'));

    Future<void> performTap(WidgetTester tester) async {
      tester.semantics.tap(find.semantics.byLabel('label'));
      await tester.pumpAndSettle();
    }

    testWidgets('does not exist under observe alone', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(tapApp(tap: TooltipTap.observe));
      expect(
        labelNode(tester).getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      handle.dispose();
    });

    testWidgets('goes to the row under observe, and opens nothing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var rowTaps = 0;
      await tester.pumpWidget(
        tapApp(tap: TooltipTap.observe, onRowTap: () => rowTaps++),
      );
      await performTap(tester);
      expect(rowTaps, 1);
      expect(find.text('Hello'), findsNothing);
      handle.dispose();
    });

    testWidgets('opens the tooltip under claim, alone or in a row', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(tapApp(tap: TooltipTap.claim));
      await performTap(tester);
      expect(find.text('Hello'), findsOneWidget);

      var rowTaps = 0;
      await tester.pumpWidget(Container());
      await tester.pumpWidget(
        tapApp(tap: TooltipTap.claim, onRowTap: () => rowTaps++),
      );
      await performTap(tester);
      expect(find.text('Hello'), findsOneWidget);
      expect(rowTaps, 0);
      handle.dispose();
    });
  });
}

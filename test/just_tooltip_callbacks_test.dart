import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

/// `onShow` reports a tooltip that was drawn, after the frame its show began
/// in; `onHide` answers only an `onShow`, and never from inside a build.
void main() {
  late List<String> log;
  late List<SchedulerPhase> hidePhases;
  late List<Object?> announced;

  setUp(() {
    log = [];
    hidePhases = [];
    announced = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
          message,
        ) async {
          final event = message as Map<Object?, Object?>;
          if (event['type'] == 'tooltip') {
            announced.add((event['data']! as Map)['message']);
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        );
  });

  Widget tooltip(
    JustTooltipController c, {
    String message = 'tip',
    Duration fade = const Duration(milliseconds: 150),
  }) => JustTooltip(
    controller: c,
    message: message,
    enableHover: false,
    animationDuration: fade,
    onShow: () => log.add('show'),
    onHide: () {
      log.add('hide');
      hidePhases.add(SchedulerBinding.instance.schedulerPhase);
    },
    child: const SizedBox(width: 60, height: 30),
  );

  Widget app(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('a tooltip removed before it is drawn reports nothing', (
    tester,
  ) async {
    final c = JustTooltipController();
    final present = ValueNotifier(true);
    await tester.pumpWidget(
      app(
        ValueListenableBuilder<bool>(
          valueListenable: present,
          builder: (_, on, _) => on ? tooltip(c) : const SizedBox(),
        ),
      ),
    );

    c.show();
    present.value = false;
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(announced, isEmpty);
  });

  testWidgets('onShow comes after the frame the show began in', (tester) async {
    final c = JustTooltipController();
    await tester.pumpWidget(app(tooltip(c)));

    c.show();
    expect(log, isEmpty);
    expect(announced, isEmpty);
    await tester.pump();
    expect(log, ['show']);
    expect(announced, ['tip']);
  });

  testWidgets('a show hidden before its first frame reports nothing', (
    tester,
  ) async {
    final c = JustTooltipController();
    await tester.pumpWidget(app(tooltip(c)));

    c.show();
    c.hide();
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(announced, isEmpty);
  });

  testWidgets('a show hidden after its first frame pairs its callbacks', (
    tester,
  ) async {
    final c = JustTooltipController();
    await tester.pumpWidget(app(tooltip(c)));

    c.show();
    await tester.pump();
    c.hide();
    await tester.pumpAndSettle();
    expect(log, ['show', 'hide']);
  });

  testWidgets('a drawn tooltip that leaves the tree calls no onHide', (
    tester,
  ) async {
    final c = JustTooltipController();
    final present = ValueNotifier(true);
    await tester.pumpWidget(
      app(
        ValueListenableBuilder<bool>(
          valueListenable: present,
          builder: (_, on, _) => on ? tooltip(c) : const SizedBox(),
        ),
      ),
    );
    c.show();
    await tester.pumpAndSettle();

    present.value = false;
    await tester.pumpAndSettle();
    expect(log, ['show']);
  });

  testWidgets('a tooltip moved after it was drawn starts its next show '
      'unreported', (tester) async {
    final c = JustTooltipController();
    final key = GlobalKey();
    final left = ValueNotifier(true);
    await tester.pumpWidget(
      app(
        ValueListenableBuilder<bool>(
          valueListenable: left,
          builder: (_, l, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 100,
                child: l
                    ? KeyedSubtree(
                        key: key,
                        child: tooltip(c, fade: Duration.zero),
                      )
                    : null,
              ),
              SizedBox(
                width: 100,
                child: l
                    ? null
                    : KeyedSubtree(
                        key: key,
                        child: tooltip(c, fade: Duration.zero),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    c.show();
    await tester.pumpAndSettle();
    left.value = false;
    await tester.pumpAndSettle();
    expect(log, ['show']);

    // Ends before its first frame, so it reports nothing.
    c.show();
    c.hide();
    await tester.pumpAndSettle();
    expect(log, ['show']);
  });

  testWidgets('a show ended and begun again in one frame reports one onShow', (
    tester,
  ) async {
    final c = JustTooltipController();
    await tester.pumpWidget(app(tooltip(c, fade: Duration.zero)));

    c.show();
    c.hide();
    c.show();
    await tester.pumpAndSettle();
    expect(log, ['show']);
    expect(announced, ['tip']);
  });

  testWidgets('losing content mid-build calls onHide after that frame', (
    tester,
  ) async {
    final c = JustTooltipController();
    final message = ValueNotifier('tip');
    await tester.pumpWidget(
      app(
        ValueListenableBuilder<String>(
          valueListenable: message,
          builder: (_, m, _) => tooltip(c, message: m, fade: Duration.zero),
        ),
      ),
    );
    c.show();
    await tester.pumpAndSettle();

    message.value = '';
    await tester.pumpAndSettle();
    expect(log, ['show', 'hide']);
    expect(hidePhases, isNot(contains(SchedulerPhase.persistentCallbacks)));
  });
}

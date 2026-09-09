// PROTOTYPE — throwaway. Branch prototype/preview-overlay, issue #53.
// Part B: the scaled frame, the ancestor clip, and the Device Wall's registry.

import 'package:flutter/material.dart';
import 'package:flutter_example_template/flutter_example_template.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

const _spec = ViewportSpec.desktop; // 1440 x 900 — will not fit, so it scales

void _sized(WidgetTester tester, Size s) {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('P6 · PreviewFrame scales via FittedBox; tooltip still hugs its target',
      (tester) async {
    // 720 wide for a 1440 viewport => 0.5x-ish after padding.
    _sized(tester, const Size(760, 620));
    final c = JustTooltipController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreviewFrame(
            spec: _spec,
            child: Center(
              child: JustTooltip(
                controller: c,
                message: 'TIP',
                // Zero padding so the text's rect IS the tooltip's rect:
                // the first run measured text-to-target and called the extra
                // 8px of padding a defect.
                theme: const JustTooltipTheme(padding: EdgeInsets.zero),
                direction: TooltipDirection.top,
                enableHover: false,
                animation: TooltipAnimation.none,
                child: Container(width: 80, height: 40, color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );
    c.show();
    await tester.pumpAndSettle();

    final target = tester.getRect(find.byType(Container).last);
    final tip = tester.getRect(find.text('TIP'));
    final scale = target.width / 80.0;
    final gap = target.top - tip.bottom;
    debugPrint('P6 scale=$scale target=$target tip=$tip gap=$gap');

    expect(scale, lessThan(1.0), reason: 'the frame must actually be scaled');
    // offset is 8 logical px inside the frame; scaled it is 8 * scale.
    expect(gap, closeTo(8 * scale, 1.0),
        reason: 'tooltip must sit one scaled offset above the scaled target');
    expect(tip.height, closeTo(20 * scale, 1.0),
        reason: 'tooltip is drawn at the frame scale, not 1:1');
  });

  testWidgets('P4 · a child clipped by a scroller INSIDE the frame aims at the visible part',
      (tester) async {
    _sized(tester, const Size(1400, 1000));
    final c = JustTooltipController();
    final controller = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PreviewStage(
              spec: ViewportSpec.mobile,
              child: Column(
                children: [
                  const SizedBox(height: 300),
                  SizedBox(
                    height: 60,
                    child: ListView(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      children: [
                        const SizedBox(width: 300),
                        JustTooltip(
                          controller: c,
                          message: 'TIP',
                          direction: TooltipDirection.bottom,
                          enableHover: false,
                          animation: TooltipAnimation.none,
                          child: Container(
                              width: 200, height: 40, color: Colors.blue),
                        ),
                        const SizedBox(width: 900),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Scroll so only the child's right part is visible at the frame's left edge.
    controller.jumpTo(420);
    await tester.pumpAndSettle();
    c.show();
    await tester.pumpAndSettle();

    final frame = tester.getRect(find.byType(PreviewStage));
    final target = tester.getRect(find.byType(Container).last);
    final tip = tester.getRect(find.text('TIP'));
    debugPrint('P4 frame=$frame');
    debugPrint('P4 target(unclipped)=$target');
    debugPrint('P4 tip=$tip');
    debugPrint('P4 visible part = ${target.intersect(frame)}');

    expect(tip.left, greaterThanOrEqualTo(frame.left),
        reason: 'aimed at the visible part, not the off-frame centre');
    expect(tip.right, lessThanOrEqualTo(frame.right));
  });

  testWidgets('P5 · Device Wall: the app-global registry lets only ONE frame show',
      (tester) async {
    _sized(tester, const Size(1400, 700));
    final cs = [
      JustTooltipController(),
      JustTooltipController(),
      JustTooltipController(),
    ];

    Widget frame(int i, {TooltipRegistry? registry}) => SizedBox(
          width: 400,
          height: 600,
          child: PreviewStage(
            spec: const ViewportSpec(
                id: 'x', label: 'x', size: Size(400, 600), showsChrome: false),
            child: Center(
              child: JustTooltip(
                controller: cs[i],
                registry: registry,
                message: 'TIP',
                enableHover: false,
                animation: TooltipAnimation.none,
                child: Container(width: 60, height: 30, color: Colors.blue),
              ),
            ),
          ),
        );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [frame(0), frame(1), frame(2)]),
      ),
    ));
    for (final c in cs) {
      c.show();
    }
    await tester.pumpAndSettle();
    final shared = find.text('TIP').evaluate().length;
    debugPrint('P5 shared registry -> $shared tooltip(s) visible');

    // Now the same wall with one registry per frame.
    final regs = [TooltipRegistry(), TooltipRegistry(), TooltipRegistry()];
    final cs2 = [
      JustTooltipController(),
      JustTooltipController(),
      JustTooltipController(),
    ];
    Widget frame2(int i) => SizedBox(
          width: 400,
          height: 600,
          child: PreviewStage(
            spec: const ViewportSpec(
                id: 'x', label: 'x', size: Size(400, 600), showsChrome: false),
            child: Center(
              child: JustTooltip(
                controller: cs2[i],
                registry: regs[i],
                message: 'TIP',
                enableHover: false,
                animation: TooltipAnimation.none,
                child: Container(width: 60, height: 30, color: Colors.blue),
              ),
            ),
          ),
        );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Row(children: [frame2(0), frame2(1), frame2(2)])),
    ));
    for (final c in cs2) {
      c.show();
    }
    await tester.pumpAndSettle();
    final isolated = find.text('TIP').evaluate().length;
    debugPrint('P5 per-frame registry -> $isolated tooltip(s) visible');

    expect(shared, 1, reason: 'app-global registry: last show wins');
    expect(isolated, 3, reason: 'a registry per frame frees the wall');
  });
}

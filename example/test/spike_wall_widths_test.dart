// PROTOTYPE — throwaway. Branch research/wall-widths, issue #58.
//
// Fact-finding only: "Which recipes may the Device Wall draw?" The Device
// Wall (flutter_example_template's `DeviceWall`) renders desktop 1440x900,
// tablet 834x1112 and mobile 390x844 at once, each in an equal Row column,
// each scaled down by its own `PreviewFrame` (FittedBox, never scales up)
// to fit that column.
//
// Four things measured per frame, using the REAL `DeviceWall` widget, at
// window widths 1800 and 1200 logical px:
//   1. auto-flip near the frame's own top edge
//   2. screenMargin clamp near the frame's own left edge
//   3. the actual FittedBox scale factor PreviewFrame lands on
//   4. rendered tooltip height as a consequence of that scale
//
// Numbers only, printed via debugPrint. No verdicts, no fixes.

import 'package:flutter/material.dart';
import 'package:flutter_example_template/flutter_example_template.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tooltip/just_tooltip.dart';

// desktop, tablet, mobile — DeviceWall's own default order.
const _specs = ViewportSpec.values;

void _sized(WidgetTester tester, Size s) {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Unscaled target sizes, chosen so on-screen size / this size == frame scale.
const _targetSize = Size(80, 40);

void main() {
  for (final window in [const Size(1800, 1000), const Size(1200, 1000)]) {
    testWidgets('Device Wall @ window=$window', (tester) async {
      _sized(tester, window);

      // One registry PER FRAME so the wall's three columns stay independent
      // (the app-global registry otherwise dismisses all but the last
      // `show()` — confirmed separately in spike_preview_overlay_b_test.dart
      // P5). Two tooltips per frame (FLIP probe, CLAMP probe) get their own
      // registry each so they do not suppress one another either.
      final flipRegs = [for (var i = 0; i < 3; i++) TooltipRegistry()];
      final clampRegs = [for (var i = 0; i < 3; i++) TooltipRegistry()];
      final flipCs = [for (var i = 0; i < 3; i++) JustTooltipController()];
      final clampCs = [for (var i = 0; i < 3; i++) JustTooltipController()];

      var callIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceWall(
              specs: _specs,
              stage: (context) {
                final i = callIndex++;
                return Stack(
                  children: [
                    // Probe A: 5px below the frame's own top edge, tooltip
                    // wants to open upward -> either flips or hits the top
                    // screenMargin. Zero tooltip padding so the tooltip's
                    // own rect is exactly the text's rect (same idiom as
                    // spike_preview_overlay_b_test.dart P6).
                    Positioned(
                      left: 150,
                      top: 5,
                      child: JustTooltip(
                        controller: flipCs[i],
                        registry: flipRegs[i],
                        message: 'FLIP',
                        direction: TooltipDirection.top,
                        enableHover: false,
                        animation: TooltipAnimation.none,
                        theme: const JustTooltipTheme(padding: EdgeInsets.zero),
                        child: Container(
                          width: _targetSize.width,
                          height: _targetSize.height,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    // Probe B: 2px from the frame's own left edge, tooltip
                    // opens upward and centers horizontally on the target ->
                    // wants to sit left of the frame's left edge, so
                    // screenMargin clamping should hold it inside.
                    Positioned(
                      left: 2,
                      top: 400,
                      child: JustTooltip(
                        controller: clampCs[i],
                        registry: clampRegs[i],
                        message: 'CLAMP',
                        direction: TooltipDirection.top,
                        enableHover: false,
                        animation: TooltipAnimation.none,
                        theme: const JustTooltipTheme(padding: EdgeInsets.zero),
                        child: Container(
                          width: _targetSize.width,
                          height: _targetSize.height,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      for (final c in [...flipCs, ...clampCs]) {
        c.show();
      }
      await tester.pumpAndSettle();

      debugPrint('=== window=$window ===');
      for (var i = 0; i < 3; i++) {
        final spec = _specs[i];
        final frame = tester.getRect(find.byType(PreviewStage).at(i));

        final flipTarget = tester.getRect(find.byType(Container).at(i * 2));
        final flipTip = tester.getRect(find.text('FLIP').at(i));
        final flipped = flipTip.top > flipTarget.top;

        final clampTarget =
            tester.getRect(find.byType(Container).at(i * 2 + 1));
        final clampTip = tester.getRect(find.text('CLAMP').at(i));

        final scale = flipTarget.width / _targetSize.width;

        debugPrint(
          '[$window] ${spec.id} (${spec.width.toInt()}x${spec.height.toInt()}): '
          'frame=$frame scale=${scale.toStringAsFixed(4)}',
        );
        debugPrint(
          '  FLIP  target=$flipTarget tip=$flipTip flipped=$flipped '
          'tipHeight=${flipTip.height.toStringAsFixed(2)}',
        );
        debugPrint(
          '  CLAMP frame.left=${frame.left.toStringAsFixed(2)} '
          'target=$clampTarget tip=$clampTip '
          'tip.left-frame.left=${(clampTip.left - frame.left).toStringAsFixed(2)}',
        );
      }

      // No assertions: this is a measurement probe, not a regression test.
      // Failing here would only mean the geometry changed shape entirely
      // (e.g. a widget went missing), which the debugPrint output already
      // makes visible.
      expect(find.text('FLIP'), findsNWidgets(3));
      expect(find.text('CLAMP'), findsNWidgets(3));
    });
  }
}

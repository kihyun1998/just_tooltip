// PROTOTYPE — throwaway. Branch prototype/preview-overlay, issue #53.
//
//   flutter run -t lib/spike_preview_overlay.dart -d chrome
//
// The numbers are in test/spike_preview_overlay_test.dart and
// test/spike_preview_overlay_b_test.dart. This is the same thing for eyes.
//
// What to look for:
//
//   1. Hover the button near each frame's TOP edge. The tooltip flips *below*
//      it, even though the window has plenty of room above the frame. Flipping
//      is measured against the frame, not the window.
//   2. Hover the button at each frame's LEFT edge. The tooltip stops at the
//      frame's margin, not the window's.
//   3. Switch to the wall. With "shared registry" only ONE frame shows a
//      tooltip at a time; with "one per frame" all three do.

import 'package:flutter/material.dart';
import 'package:flutter_example_template/flutter_example_template.dart';
import 'package:just_tooltip/just_tooltip.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatefulWidget {
  const SpikeApp({super.key});
  @override
  State<SpikeApp> createState() => _SpikeAppState();
}

class _SpikeAppState extends State<SpikeApp> {
  String _viewport = ViewportSpec.mobile.id;
  bool _perFrameRegistry = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: exampleTheme(Brightness.light),
      darkTheme: exampleTheme(Brightness.dark),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('PROTOTYPE · tooltip inside PreviewStage (#53)'),
          actions: [
            Row(
              children: [
                const Text('one registry per frame'),
                Switch(
                  value: _perFrameRegistry,
                  onChanged: (v) => setState(() => _perFrameRegistry = v),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: ViewportBar(
                selectedId: _viewport,
                showsWall: true,
                onChanged: (id) => setState(() => _viewport = id),
              ),
            ),
            Expanded(
              child: _viewport == ViewportBar.wallId
                  ? DeviceWall(
                      // A builder, so each frame gets its own element — which
                      // is what lets _Subject's State own a registry per frame.
                      stage: (context) =>
                          _Subject(perFrame: _perFrameRegistry),
                    )
                  : PreviewFrame(
                      spec: ViewportSpec.byId(_viewport),
                      child: _Subject(perFrame: _perFrameRegistry),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Each frame builds its own instance, so its own State — which is exactly what
/// makes a per-frame registry possible without the shell knowing about tooltips.
class _Subject extends StatefulWidget {
  const _Subject({required this.perFrame});
  final bool perFrame;
  @override
  State<_Subject> createState() => _SubjectState();
}

class _SubjectState extends State<_Subject> {
  late final TooltipRegistry _mine = TooltipRegistry();
  final _c = JustTooltipController();

  @override
  Widget build(BuildContext context) {
    final registry = widget.perFrame ? _mine : null;

    Widget tip(String label, {TooltipDirection dir = TooltipDirection.top}) =>
        JustTooltip(
          message: '$label — measured against the frame',
          direction: dir,
          registry: registry,
          child: FilledButton(onPressed: () {}, child: Text(label)),
        );

    return Stack(
      children: [
        Positioned(top: 4, left: 120, child: tip('top edge')),
        Positioned(left: 0, top: 200, child: tip('left edge')),
        Positioned(
          right: 0,
          bottom: 4,
          child: tip('bottom-right', dir: TooltipDirection.bottom),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              JustTooltip(
                controller: _c,
                registry: registry,
                message: 'shown by controller',
                child: const Icon(Icons.center_focus_strong, size: 40),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _c.toggle,
                child: const Text('toggle (drives the wall)'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

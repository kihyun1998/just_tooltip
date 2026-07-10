// Spike: the shape that motivated #21, #22, #24, #26 and #33 — a horizontally
// scrolling table whose rows are far wider than the viewport, each row showing
// a rich card, each truncated cell keeping its own "here is the full text"
// tooltip.
//
//   flutter run -t lib/spike_wide_row.dart -d chrome
//
// What to look for:
//
//   1. Hover a row's gutter → the card appears BESIDE THE CURSOR, wherever you
//      are along the 3000px row. Flip the switch to `child` to watch it snap to
//      the centre of whatever part of the row is on screen — on screen, but
//      unrelated to the pointer. (#21)
//   2. Hover a truncated cell → only the cell's tooltip shows, never both.
//      Slide back off the cell onto the row → the card returns without leaving
//      the row. (#22)
//   3. Move the cursor onto the card itself → it stays, and you can scroll it.
//      It does not chase the cursor, and it does not vanish under it. Move back
//      off the card onto the row → it still stays. Both crossings are covered by
//      the same 100ms grace window. (#21, #26, #43)
//   4. The whole table lives in an Overlay inset from the window. Tooltips are
//      still positioned against their target, not displaced by the inset. (#24)
//
// Since #33 a child anchor targets the child's *visible* rect. A row is always
// wider than the viewport, so that intersection is the viewport itself: the
// card lands at its centre and stays there as you scroll. That also hides the
// per-frame re-aiming of #35, which only shows on a child small enough to move
// around inside its clip — a cell, not a row.

import 'package:flutter/material.dart';
import 'package:just_tooltip/just_tooltip.dart';

void main() => runApp(const SpikeApp());

const _cellWidth = 300.0;
const _cellCount = 10;
const _rowCount = 8;
const _rowPadding = 24.0;
const _rowWidth = _cellCount * _cellWidth + _rowPadding * 2;

/// The Overlay is inset from the window, so window coords and Overlay coords
/// disagree. Before #24 every tooltip here was displaced by this much.
const _overlayInset = EdgeInsets.fromLTRB(48, 0, 48, 48);

class SpikeApp extends StatefulWidget {
  const SpikeApp({super.key});

  @override
  State<SpikeApp> createState() => _SpikeAppState();
}

class _SpikeAppState extends State<SpikeApp> {
  TooltipAnchor _anchor = TooltipAnchor.pointer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Wide-row tooltips'),
          actions: [
            Row(
              children: [
                Text('anchor: ${_anchor.name}'),
                Switch(
                  value: _anchor == TooltipAnchor.pointer,
                  onChanged: (on) => setState(
                    () => _anchor = on
                        ? TooltipAnchor.pointer
                        : TooltipAnchor.child,
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ],
        ),
        body: Padding(
          padding: _overlayInset,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Overlay(
              initialEntries: [
                OverlayEntry(builder: (context) => _Table(anchor: _anchor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.anchor});

  final TooltipAnchor anchor;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _rowWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _rowCount; i++) _Row(index: i, anchor: anchor),
          ],
        ),
      ),
    );
  }
}

/// A row-level tooltip whose hover region is the whole 3000px row, so the card
/// does not blink off as the cursor crosses the column gutters.
class _Row extends StatelessWidget {
  const _Row({required this.index, required this.anchor});

  final int index;
  final TooltipAnchor anchor;

  @override
  Widget build(BuildContext context) {
    return JustTooltip(
      anchor: anchor,
      direction: TooltipDirection.bottom,
      tooltipBuilder: (context) => _RowCard(index: index),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: index.isEven ? Colors.grey.shade50 : Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        // Generous padding: dead space under the old cell-per-tooltip
        // workaround, live hover region for the row.
        padding: const EdgeInsets.symmetric(
          horizontal: _rowPadding,
          vertical: 12,
        ),
        child: Row(
          children: [
            for (var c = 0; c < _cellCount; c++)
              SizedBox(
                width: _cellWidth,
                child: _Cell(row: index, col: c),
              ),
          ],
        ),
      ),
    );
  }
}

/// Every third cell is "truncated" and keeps its own tooltip. Hovering it must
/// suppress the row's card — the innermost tooltip wins.
class _Cell extends StatelessWidget {
  const _Cell({required this.row, required this.col});

  final int row;
  final int col;

  @override
  Widget build(BuildContext context) {
    final truncated = col % 3 == 0;
    final label = 'r$row·c$col';

    if (!truncated) {
      return Text(label, style: const TextStyle(color: Colors.black54));
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: JustTooltip(
        // The cell tooltip anchors at the pointer too, so it appears on the
        // word the cursor is over rather than the cell's centre.
        anchor: TooltipAnchor.pointer,
        message:
            'Full value for $label — the cell shows an ellipsis because '
            'the column is too narrow to hold this sentence.',
        child: SizedBox(
          width: 160,
          child: Text(
            '$label — a long value that will not fit here',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.indigo,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Interactive content: the cursor must be able to reach and scroll it, which
/// is only possible because the anchor is frozen at show time.
class _RowCard extends StatelessWidget {
  const _RowCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 180,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Row $index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < 8; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'detail line $i for row $index',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

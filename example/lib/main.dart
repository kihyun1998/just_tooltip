import 'package:flutter/material.dart';
import 'package:just_tooltip/just_tooltip.dart';

void main() {
  runApp(const PlaygroundApp());
}

// =============================================================================
// App root — theme switching
// =============================================================================

class PlaygroundApp extends StatefulWidget {
  const PlaygroundApp({super.key});

  @override
  State<PlaygroundApp> createState() => _PlaygroundAppState();
}

class _PlaygroundAppState extends State<PlaygroundApp> {
  ThemeMode _themeMode = ThemeMode.light;
  Color _seedColor = Colors.deepPurple;

  static const _seedColors = <String, Color>{
    'Deep Purple': Colors.deepPurple,
    'Blue': Colors.blue,
    'Teal': Colors.teal,
    'Orange': Colors.orange,
    'Pink': Colors.pink,
    'Green': Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JustTooltip Playground',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: PlaygroundPage(
        themeMode: _themeMode,
        seedColor: _seedColor,
        seedColors: _seedColors,
        onThemeModeChanged: (m) => setState(() => _themeMode = m),
        onSeedColorChanged: (c) => setState(() => _seedColor = c),
      ),
    );
  }
}

// =============================================================================
// Main playground page
// =============================================================================

class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({
    super.key,
    required this.themeMode,
    required this.seedColor,
    required this.seedColors,
    required this.onThemeModeChanged,
    required this.onSeedColorChanged,
  });

  final ThemeMode themeMode;
  final Color seedColor;
  final Map<String, Color> seedColors;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Color> onSeedColorChanged;

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  static const _curvePresets = <String, Curve>{
    'easeInOut': Curves.easeInOut,
    'easeIn': Curves.easeIn,
    'easeOut': Curves.easeOut,
    'linear': Curves.linear,
    'bounceOut': Curves.bounceOut,
    'elasticOut': Curves.elasticOut,
    'decelerate': Curves.decelerate,
    'fastOutSlowIn': Curves.fastOutSlowIn,
  };

  // Tooltip configuration
  TooltipDirection _direction = TooltipDirection.top;
  TooltipAlignment _alignment = TooltipAlignment.center;
  double _offset = 8.0;
  double _crossAxisOffset = 0.0;
  double _screenMargin = 8.0;
  double _elevation = 4.0;
  double _borderRadiusVal = 6.0;
  bool _enableTap = true;
  bool _enableHover = true;
  bool _interactive = true;
  int _waitDurationMs = 0;
  int _showDurationMs = 0;
  int _animDurationMs = 150;
  TooltipAnimation _animation = TooltipAnimation.fade;
  String _curveName = 'easeInOut';
  double _fadeBegin = 0.0;
  double _scaleBegin = 0.0;
  double _slideOffsetVal = 0.3;
  double _rotationBegin = -0.05;
  bool _showArrow = false;
  double _arrowPositionRatio = 0.25;
  bool _useBorder = false;
  Color _borderColor = Colors.white;
  double _borderWidth = 1.0;
  bool _useCustomContent = false;
  bool _useBoxShadow = false;
  double _shadowBlurRadius = 4.0;
  double _shadowSpreadRadius = 0.0;
  double _shadowOffsetX = 0.0;
  double _shadowOffsetY = 2.0;
  double _shadowOpacity = 0.3;
  Color _tooltipBg = const Color(0xFF616161);

  String _tooltipMessage = 'Hello from JustTooltip!';
  late final TextEditingController _messageController;

  // Controller demo
  final _controller = JustTooltipController();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: _tooltipMessage);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JustTooltip Playground'),
        actions: [
          // Theme mode toggle
          IconButton(
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Toggle theme',
            onPressed: () {
              widget.onThemeModeChanged(
                widget.themeMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              );
            },
          ),
          // Seed color picker
          PopupMenuButton<Color>(
            icon: Icon(Icons.palette, color: widget.seedColor),
            tooltip: 'Theme color',
            onSelected: widget.onSeedColorChanged,
            itemBuilder: (_) => widget.seedColors.entries
                .map(
                  (e) => PopupMenuItem(
                    value: e.value,
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: e.value, radius: 10),
                        const SizedBox(width: 12),
                        Text(e.key),
                        if (e.value == widget.seedColor) ...[
                          const Spacer(),
                          const Icon(Icons.check, size: 18),
                        ],
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: Row(
        children: [
          // ── Left: Control panel ──
          SizedBox(width: 320, child: _buildControlPanel(cs)),
          const VerticalDivider(width: 1),
          // ── Right: Preview area ──
          Expanded(child: _buildPreviewArea(cs)),
        ],
      ),
    );
  }

  // ===========================================================================
  // Control panel
  // ===========================================================================

  Widget _buildControlPanel(ColorScheme cs) {
    return ListView(
      children: [
        _section(
          title: 'Position',
          initiallyExpanded: true,
          children: [
            _enumSelector<TooltipDirection>(
              values: TooltipDirection.values,
              current: _direction,
              onChanged: (v) => setState(() => _direction = v),
            ),
            const SizedBox(height: 12),
            _enumSelector<TooltipAlignment>(
              values: TooltipAlignment.values,
              current: _alignment,
              onChanged: (v) => setState(() => _alignment = v),
            ),
            const SizedBox(height: 4),
            _slider('Offset (gap)', _offset, 0, 24, (v) {
              setState(() => _offset = v);
            }),
            _slider('Cross-axis offset', _crossAxisOffset, -30, 30, (v) {
              setState(() => _crossAxisOffset = v);
            }),
            _slider('Screen margin', _screenMargin, 0, 64, (v) {
              setState(() => _screenMargin = v);
            }),
          ],
        ),
        _section(
          title: 'Trigger',
          initiallyExpanded: true,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Hover', _enableHover, (v) {
                  setState(() => _enableHover = v);
                }),
                _chip('Tap', _enableTap, (v) {
                  setState(() => _enableTap = v);
                }),
                _chip('Interactive', _interactive, (v) {
                  setState(() => _interactive = v);
                }),
              ],
            ),
          ],
        ),
        _section(
          title: 'Style',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Arrow', _showArrow, (v) {
                  setState(() => _showArrow = v);
                }),
                _chip('Border', _useBorder, (v) {
                  setState(() => _useBorder = v);
                }),
              ],
            ),
            if (_showArrow) ...[
              const SizedBox(height: 8),
              _slider('Arrow position ratio', _arrowPositionRatio, 0, 1, (v) {
                setState(() => _arrowPositionRatio = v);
              }),
            ],
            if (_useBorder) ...[
              const SizedBox(height: 8),
              _slider('Border width', _borderWidth, 0.5, 4, (v) {
                setState(() => _borderWidth = v);
              }),
              const SizedBox(height: 4),
              Text(
                'Border color',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _borderColorDot(Colors.white),
                  _borderColorDot(Colors.black),
                  _borderColorDot(cs.primary),
                  _borderColorDot(cs.error),
                  _borderColorDot(Colors.amber),
                  _borderColorDot(Colors.cyan),
                ],
              ),
            ],
            const SizedBox(height: 8),
            _slider('Elevation', _elevation, 0, 16, (v) {
              setState(() => _elevation = v);
            }),
            _slider('Border radius', _borderRadiusVal, 0, 20, (v) {
              setState(() => _borderRadiusVal = v);
            }),
            const SizedBox(height: 8),
            Text('Background', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _colorDot(const Color(0xFF616161)),
                _colorDot(Colors.black87),
                _colorDot(cs.primary),
                _colorDot(cs.secondary),
                _colorDot(cs.tertiary),
                _colorDot(cs.error),
                _colorDot(Colors.teal),
                _colorDot(Colors.indigo),
              ],
            ),
          ],
        ),
        _section(
          title: 'Shadow',
          children: [
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Use BoxShadow'),
              subtitle: const Text('elevation is ignored when enabled'),
              value: _useBoxShadow,
              onChanged: (v) => setState(() => _useBoxShadow = v),
            ),
            if (_useBoxShadow) ...[
              _slider('Blur radius', _shadowBlurRadius, 0, 20, (v) {
                setState(() => _shadowBlurRadius = v);
              }),
              _slider('Spread radius', _shadowSpreadRadius, -5, 10, (v) {
                setState(() => _shadowSpreadRadius = v);
              }),
              _slider('Offset X', _shadowOffsetX, -10, 10, (v) {
                setState(() => _shadowOffsetX = v);
              }),
              _slider('Offset Y', _shadowOffsetY, -10, 10, (v) {
                setState(() => _shadowOffsetY = v);
              }),
              _slider('Opacity', _shadowOpacity, 0, 1, (v) {
                setState(() => _shadowOpacity = v);
              }),
            ],
          ],
        ),
        _section(
          title: 'Timing',
          children: [
            _slider('Wait duration (ms)', _waitDurationMs.toDouble(), 0, 1000, (
              v,
            ) {
              setState(() => _waitDurationMs = v.round());
            }),
            _slider('Show duration (ms)', _showDurationMs.toDouble(), 0, 5000, (
              v,
            ) {
              setState(() => _showDurationMs = v.round());
            }),
            _slider('Animation (ms)', _animDurationMs.toDouble(), 0, 500, (v) {
              setState(() => _animDurationMs = v.round());
            }),
          ],
        ),
        _section(
          title: 'Animation',
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Animation type',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TooltipAnimation>(
                  value: _animation,
                  isDense: true,
                  isExpanded: true,
                  items: TooltipAnimation.values
                      .map(
                        (a) => DropdownMenuItem(value: a, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _animation = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Curve',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _curveName,
                  isDense: true,
                  isExpanded: true,
                  items: _curvePresets.keys
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _curveName = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            _slider('Fade begin', _fadeBegin, 0, 1, (v) {
              setState(() => _fadeBegin = v);
            }),
            _slider('Scale begin', _scaleBegin, 0, 1, (v) {
              setState(() => _scaleBegin = v);
            }),
            _slider('Slide offset', _slideOffsetVal, 0, 1, (v) {
              setState(() => _slideOffsetVal = v);
            }),
            _slider('Rotation begin', _rotationBegin, -0.25, 0.25, (v) {
              setState(() => _rotationBegin = v);
            }),
          ],
        ),
        _section(
          title: 'Content',
          initiallyExpanded: true,
          children: [
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Custom widget'),
              value: _useCustomContent,
              onChanged: (v) => setState(() => _useCustomContent = v),
            ),
            if (!_useCustomContent) ...[
              const SizedBox(height: 4),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Tooltip message',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                controller: _messageController,
                onChanged: (v) => setState(() => _tooltipMessage = v),
              ),
            ],
          ],
        ),
        _section(
          title: 'Controller',
          initiallyExpanded: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _controller.show,
                    child: const Text('show()'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _controller.hide,
                    child: const Text('hide()'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _controller.toggle,
                    child: const Text('toggle()'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // Preview area
  // ===========================================================================

  Widget _buildPreviewArea(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerLowest,
      child: Column(
        children: [
          // Interactive preview (center)
          Expanded(child: Center(child: _buildTooltipDemo(cs))),
          // Quick presets bar
          _buildPresetsBar(cs),
        ],
      ),
    );
  }

  Widget _buildTooltipDemo(ColorScheme cs) {
    return JustTooltip(
      controller: _controller,
      direction: _direction,
      alignment: _alignment,
      offset: _offset,
      crossAxisOffset: _crossAxisOffset,
      screenMargin: _screenMargin,
      theme: JustTooltipTheme(
        backgroundColor: _tooltipBg,
        borderRadius: BorderRadius.circular(_borderRadiusVal),
        elevation: _elevation,
        boxShadow: _useBoxShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _shadowOpacity),
                  blurRadius: _shadowBlurRadius,
                  spreadRadius: _shadowSpreadRadius,
                  offset: Offset(_shadowOffsetX, _shadowOffsetY),
                ),
              ]
            : null,
        showArrow: _showArrow,
        arrowPositionRatio: _arrowPositionRatio,
        borderColor: _useBorder ? _borderColor : null,
        borderWidth: _useBorder ? _borderWidth : 0,
      ),
      enableTap: _enableTap,
      enableHover: _enableHover,
      interactive: _interactive,
      waitDuration: _waitDurationMs > 0
          ? Duration(milliseconds: _waitDurationMs)
          : null,
      showDuration: _showDurationMs > 0
          ? Duration(milliseconds: _showDurationMs)
          : null,
      animation: _animation,
      animationCurve: _curvePresets[_curveName],
      fadeBegin: _fadeBegin,
      scaleBegin: _scaleBegin,
      slideOffset: _slideOffsetVal,
      rotationBegin: _rotationBegin,
      animationDuration: Duration(milliseconds: _animDurationMs),
      message: _useCustomContent ? null : _tooltipMessage,
      tooltipBuilder: _useCustomContent
          ? (context) => _customTooltipContent(cs)
          : null,
      child: Container(
        width: 280,
        height: 56,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          _enableHover && _enableTap
              ? 'Hover or Tap me'
              : _enableTap
              ? 'Tap me'
              : _enableHover
              ? 'Hover me'
              : 'Use controller',
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _customTooltipContent(ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.info_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom tooltip',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              'Built with tooltipBuilder',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // Presets bar
  // ===========================================================================

  Widget _buildPresetsBar(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Presets',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _presetChip(
                'Top-Center',
                TooltipDirection.top,
                TooltipAlignment.center,
                cs,
              ),
              _presetChip(
                'Top-Start',
                TooltipDirection.top,
                TooltipAlignment.start,
                cs,
              ),
              _presetChip(
                'Top-End',
                TooltipDirection.top,
                TooltipAlignment.end,
                cs,
              ),
              _presetChip(
                'Bottom-Center',
                TooltipDirection.bottom,
                TooltipAlignment.center,
                cs,
              ),
              _presetChip(
                'Left-Center',
                TooltipDirection.left,
                TooltipAlignment.center,
                cs,
              ),
              _presetChip(
                'Right-Center',
                TooltipDirection.right,
                TooltipAlignment.center,
                cs,
              ),
              _presetChip(
                'Right-End',
                TooltipDirection.right,
                TooltipAlignment.end,
                cs,
              ),
              _presetChip(
                'Bottom-Start',
                TooltipDirection.bottom,
                TooltipAlignment.start,
                cs,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetChip(
    String label,
    TooltipDirection dir,
    TooltipAlignment align,
    ColorScheme cs,
  ) {
    final isActive = _direction == dir && _alignment == align;
    return ActionChip(
      label: Text(label),
      backgroundColor: isActive ? cs.primaryContainer : null,
      side: isActive ? BorderSide(color: cs.primary, width: 1.5) : null,
      onPressed: () {
        setState(() {
          _direction = dir;
          _alignment = align;
        });
      },
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  Widget _section({
    required String title,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return ExpansionTile(
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: children,
    );
  }

  Widget _enumSelector<T extends Enum>({
    required List<T> values,
    required T current,
    required ValueChanged<T> onChanged,
  }) {
    return SegmentedButton<T>(
      segments: values
          .map((v) => ButtonSegment(value: v, label: Text(v.name)))
          .toList(),
      selected: {current},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _chip(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(
              value == value.roundToDouble()
                  ? value.round().toString()
                  : value.toStringAsFixed(1),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _colorDot(Color color) {
    final selected = _tooltipBg.toARGB32() == color.toARGB32();
    return GestureDetector(
      onTap: () => setState(() => _tooltipBg = color),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2.5,
                )
              : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
    );
  }

  Widget _borderColorDot(Color color) {
    final selected = _borderColor.toARGB32() == color.toARGB32();
    return GestureDetector(
      onTap: () => setState(() => _borderColor = color),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2.5,
                )
              : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
    );
  }
}

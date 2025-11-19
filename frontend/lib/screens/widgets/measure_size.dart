
import 'package:flutter/material.dart';

class MeasureSize extends StatefulWidget {
  final Widget child;
  final void Function(Size size) onChange;

  const MeasureSize({
    Key? key,
    required this.onChange,
    required this.child,
  }) : super(key: key);

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? _oldSize;
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!mounted) return; // widget no longer in tree

        final renderObject = context.findRenderObject();
        if (renderObject is RenderBox && renderObject.hasSize) {
          final size = renderObject.size;
          if (_oldSize == null || _oldSize != size) {
            _oldSize = size;
            widget.onChange(size);
          }
        }
      } catch (e) {
        // Defensive: if element is defunct or size access fails, skip.
      }
    });
    return widget.child;
  }
}
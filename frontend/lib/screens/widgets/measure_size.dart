
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
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = context.size;
      if (size != null) {
        widget.onChange(size);
      }
    });
    return widget.child;
  }
}
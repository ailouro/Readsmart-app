import 'package:flutter/material.dart';

/// Drop this around ANY tappable widget (a card, an icon, a chip, a tab)
/// to give it three layers of tactile feedback that plain [GestureDetector]
/// doesn't provide on its own:
///
/// 1. A circular "bubble" ripple that spreads out from the tap point
///    (Android's native splash effect — via [InkWell]).
/// 2. A soft highlight when the mouse hovers over it (web/desktop).
/// 3. A quick scale-down "squish" on press that springs back on release,
///    for that satisfying bouncy-button feel.
///
/// Usage — just wrap the existing child, keep the same onTap:
/// ```dart
/// BouncyTap(
///   onTap: () => setState(() => _selectedClassIndex = i),
///   borderRadius: BorderRadius.circular(30),
///   child: yourExistingContainer,
/// )
/// ```
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? splashColor;
  final Color? hoverColor;
  final double pressedScale;

  const BouncyTap({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.splashColor,
    this.hoverColor,
    this.pressedScale = 0.94,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    if (widget.onTap == null) return;
    setState(() => _scale = pressed ? widget.pressedScale : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: widget.borderRadius,
            splashColor: widget.splashColor ?? const Color(0x33940D0D),
            highlightColor: widget.hoverColor ?? const Color(0x11940D0D),
            hoverColor: widget.hoverColor ?? const Color(0x11940D0D),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

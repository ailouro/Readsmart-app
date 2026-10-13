import 'package:flutter/material.dart';

/// Shared desktop helpers for ReadSmart.
///
/// Phones and small windows (narrower than [DesktopLayout.breakpoint]) are
/// never changed. Only wide windows (the Windows app, web, landscape tablets)
/// get larger text and a roomier, centered layout.
class DesktopLayout {
  const DesktopLayout._();

  /// Windows at or above this width use the desktop sizing and structure.
  static const double breakpoint = 900;

  /// Text size multiplier used on desktop only. Raise it for bigger text,
  /// lower it for smaller text. Mobile is not affected.
  static const double textScale = 1.25;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpoint;
}

/// Makes all text inside [child] larger on desktop. Does nothing on mobile.
///
/// The scale is absolute (not multiplied), so wrapping a widget that is
/// already inside another [DesktopTextScale] never scales the text twice.
class DesktopTextScale extends StatelessWidget {
  final Widget child;
  final double scale;

  const DesktopTextScale({
    super.key,
    required this.child,
    this.scale = DesktopLayout.textScale,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < DesktopLayout.breakpoint) return child;
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    );
  }
}

/// Centers [child] and limits its width on desktop so lists and forms do not
/// stretch across the whole window. Does nothing on mobile.
class DesktopContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const DesktopContent({super.key, required this.child, this.maxWidth = 1100});

  @override
  Widget build(BuildContext context) {
    if (!DesktopLayout.isDesktop(context)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

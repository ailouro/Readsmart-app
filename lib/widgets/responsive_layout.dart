import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget? tabletLayout;
  final Widget desktopLayout;

  const ResponsiveLayout({
    super.key,
    required this.mobileLayout,
    this.tabletLayout,
    required this.desktopLayout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1024) {
          return desktopLayout;
        } else if (constraints.maxWidth >= 600) {
          return tabletLayout ?? mobileLayout;
        } else {
          return mobileLayout;
        }
      },
    );
  }
}

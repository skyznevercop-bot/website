import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Responsive layout utilities.
class Responsive {
  Responsive._();

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppConstants.mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= AppConstants.mobileBreakpoint &&
        w < AppConstants.desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;

  /// Returns a value based on the current breakpoint.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  /// Horizontal padding that adapts to screen size.
  static EdgeInsets horizontalPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: value(context, mobile: 16.0, tablet: 32.0, desktop: 48.0),
    );
  }

  /// Current screen width shorthand.
  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Returns [desired] clamped so it fits within the screen minus [margin].
  static double clampedWidth(BuildContext context, double desired,
      {double margin = 48}) {
    final maxWidth = screenWidth(context) - margin;
    return desired.clamp(0.0, maxWidth);
  }
}

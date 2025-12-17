import 'package:flutter/material.dart';

/// Comprehensive utility class for responsive sizing
/// Optimized for phones ranging from small (360px) to large (430px+)
class ScreenUtils {
  // Singleton pattern for caching MediaQuery data
  static double? _cachedWidth;
  static double? _cachedHeight;
  static double? _cachedTextScale;

  /// Initialize cached values (call once per frame if needed)
  static void init(BuildContext context) {
    final mq = MediaQuery.of(context);
    _cachedWidth = mq.size.width;
    _cachedHeight = mq.size.height;
    _cachedTextScale = mq.textScaler.scale(1.0);
  }

  /// Screen breakpoints
  static const double smallPhone = 360;
  static const double mediumPhone = 393;
  static const double largePhone = 430;
  static const double tablet = 600;

  /// Get screen width
  static double width(BuildContext context) {
    return _cachedWidth ?? MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double height(BuildContext context) {
    return _cachedHeight ?? MediaQuery.of(context).size.height;
  }

  /// Check device size category
  static bool isSmallPhone(BuildContext context) => width(context) < smallPhone;
  static bool isMediumPhone(BuildContext context) =>
      width(context) >= smallPhone && width(context) < largePhone;
  static bool isLargePhone(BuildContext context) =>
      width(context) >= largePhone && width(context) < tablet;
  static bool isTablet(BuildContext context) => width(context) >= tablet;

  /// Get responsive font size with clamp for safety
  static double getFontSize(BuildContext context, double baseSize) {
    final w = width(context);
    final scale = (w / mediumPhone).clamp(0.85, 1.2);
    return (baseSize * scale).clamp(baseSize * 0.8, baseSize * 1.3);
  }

  /// Get responsive padding with screen-aware scaling
  static double getPadding(BuildContext context, double basePadding) {
    final w = width(context);
    if (w < smallPhone) return basePadding * 0.85;
    if (w > largePhone) return basePadding * 1.1;
    return basePadding * (w / mediumPhone);
  }

  /// Get responsive horizontal padding (for edge margins)
  static double getHorizontalPadding(BuildContext context) {
    final w = width(context);
    if (w < smallPhone) return 12;
    if (w < mediumPhone) return 16;
    if (w < largePhone) return 20;
    return 24;
  }

  /// Get responsive vertical spacing
  static double getSpacing(BuildContext context, double baseSpacing) {
    final h = height(context);
    // Scale based on height (873px is reference)
    final scale = (h / 873).clamp(0.85, 1.2);
    return baseSpacing * scale;
  }

  /// Get responsive icon size with bounds
  static double getIconSize(BuildContext context, double baseSize) {
    final w = width(context);
    final scale = (w / mediumPhone).clamp(0.9, 1.15);
    return baseSize * scale;
  }

  /// Get optimal button height (minimum 48dp for touch targets)
  static double getButtonHeight(BuildContext context) {
    final h = height(context);
    return (h * 0.055).clamp(44.0, 56.0);
  }

  /// Get responsive border radius
  static double getBorderRadius(BuildContext context, double baseRadius) {
    final w = width(context);
    if (w < smallPhone) return baseRadius * 0.85;
    return baseRadius;
  }

  /// Get responsive card padding
  static EdgeInsets getCardPadding(BuildContext context) {
    final p = getPadding(context, 16);
    return EdgeInsets.all(p);
  }

  /// Get responsive screen padding (for main screens)
  static EdgeInsets getScreenPadding(BuildContext context) {
    final h = getHorizontalPadding(context);
    final v = getSpacing(context, 16);
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  /// Get aspect ratio aware sizing for cards
  static double getCardWidth(BuildContext context) {
    final w = width(context);
    return w - (getHorizontalPadding(context) * 2);
  }

  /// Responsive text style factory
  static TextStyle responsiveText(
    BuildContext context, {
    required double baseSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontSize: getFontSize(context, baseSize),
      fontWeight: fontWeight,
      color: color,
    );
  }
}

/// Extension for easier MediaQuery access
extension ContextExtension on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isSmallScreen => screenWidth < 360;
  bool get isLandscape =>
      MediaQuery.of(this).orientation == Orientation.landscape;
  EdgeInsets get viewPadding => MediaQuery.of(this).viewPadding;
}

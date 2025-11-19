import 'package:flutter/material.dart';

/// Utility class for device-specific sizing
/// Optimized for IQOO Z6 Pro: 393x873 (density 2.5)
class ScreenUtils {
  /// Get responsive font size based on screen width
  static double getFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    // For 393px width, scale appropriately
    if (width <= 400) {
      return baseSize * (width / 393);
    }
    return baseSize;
  }

  /// Get responsive padding
  static double getPadding(BuildContext context, double basePadding) {
    final width = MediaQuery.of(context).size.width;
    if (width <= 400) {
      return basePadding * (width / 393);
    }
    return basePadding;
  }

  /// Get responsive icon size
  static double getIconSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width <= 400) {
      return baseSize * (width / 393);
    }
    return baseSize;
  }

  /// Get responsive spacing
  static double getSpacing(BuildContext context, double baseSpacing) {
    final height = MediaQuery.of(context).size.height;
    if (height <= 900) {
      return baseSpacing * (height / 873);
    }
    return baseSpacing;
  }

  /// Check if device is small (width <= 400)
  static bool isSmallDevice(BuildContext context) {
    return MediaQuery.of(context).size.width <= 400;
  }

  /// Get optimal button height for touch targets (minimum 48dp)
  static double getButtonHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    // Ensure minimum 48dp touch target
    return height * 0.055; // ~48dp for 873px height
  }
}


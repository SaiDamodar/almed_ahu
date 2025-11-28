import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AhuDashboardApp());
}

/// Custom scroll behavior that:
/// - Hides scrollbars completely (no side scrollbar)
/// - Enables touch scrolling on all devices
/// - Uses bouncing physics for natural touch feel
class TouchFriendlyScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    // Return child directly without wrapping in Scrollbar - hides scrollbar completely
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use bouncing physics for natural touch feel
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class AhuDashboardApp extends StatelessWidget {
  const AhuDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'AHU Control Dashboard',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            // Apply global touch-friendly scroll behavior (no scrollbar, touch/drag everywhere)
            scrollBehavior: TouchFriendlyScrollBehavior(),
            home: const LoginScreen(),
          );
        },
      ),
    );
  }
}

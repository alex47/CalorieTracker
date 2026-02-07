import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'screens/about_screen.dart';
import 'screens/add_entry_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/database_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.initialize();
  await SettingsService.instance.initialize();
  runApp(const CalorieTrackerApp());
}

class CalorieTrackerApp extends StatelessWidget {
  const CalorieTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const buttonBackground = Color(0xFF1E3A8A);
    const buttonForeground = Color(0xFFF1F5FF);
    const pageBackground = Color(0xFF212121);
    const textColor = Color(0xFFCBCBCB);
    const boxBackground = Color(0xFF181818);
    const borderColor = Color(0xFF343434);
    // Single typography scale for the whole app.
    const textSizeXSmall = 12.0;
    const textSizeSmall = 14.0;
    const textSizeMedium = 16.0;
    const textSizeLarge = 22.0;

    final baseTextTheme = ThemeData.dark().textTheme.apply(
          bodyColor: textColor,
          displayColor: textColor,
        );
    final appTextTheme = baseTextTheme.copyWith(
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: textSizeLarge,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: textSizeLarge,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: textSizeMedium,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: textSizeSmall,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: textSizeMedium,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: textSizeSmall,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: textSizeXSmall,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: textSizeSmall,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: textSizeXSmall,
      ),
    );

    return MaterialApp(
      title: 'Calorie Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: buttonBackground, brightness: Brightness.dark)
            .copyWith(
              primary: buttonBackground,
              onPrimary: buttonForeground,
              surface: boxBackground,
              surfaceContainerHighest: boxBackground,
              onSurface: textColor,
              onSurfaceVariant: textColor,
              outline: borderColor,
            ),
        scaffoldBackgroundColor: pageBackground,
        cardTheme: const CardThemeData(
          color: boxBackground,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: borderColor),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: borderColor,
          thickness: 1,
        ),
        textTheme: appTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: boxBackground,
          foregroundColor: textColor,
          titleTextStyle: appTextTheme.titleLarge?.copyWith(
            color: textColor,
            fontSize: textSizeLarge,
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          textStyle: appTextTheme.bodyMedium?.copyWith(
            fontSize: textSizeMedium,
            color: textColor,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: borderColor, width: 2),
          ),
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: borderColor),
          ),
          labelStyle: appTextTheme.bodyLarge?.copyWith(
            color: textColor,
            fontSize: textSizeMedium,
          ),
          floatingLabelStyle: appTextTheme.bodyLarge?.copyWith(
            color: textColor,
            fontSize: textSizeMedium,
          ),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: textColor,
          selectionHandleColor: textColor,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: buttonBackground,
            foregroundColor: buttonForeground,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: appTextTheme.labelLarge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: buttonBackground,
          foregroundColor: buttonForeground,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      routes: {
        SettingsScreen.routeName: (_) => const SettingsScreen(),
        AboutScreen.routeName: (_) => const AboutScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == AddEntryScreen.routeName) {
          final args = settings.arguments;
          final date = args is DateTime ? args : DateTime.now();
          return MaterialPageRoute(
            builder: (_) => AddEntryScreen(date: date),
          );
        }
        return null;
      },
      home: const HomeScreen(),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
    );
  }
}

String formatDate(DateTime date) {
  return DateFormat.yMMMMd().format(date);
}

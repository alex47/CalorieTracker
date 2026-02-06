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
        appBarTheme: const AppBarTheme(
          backgroundColor: boxBackground,
          foregroundColor: textColor,
        ),
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
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: textColor,
              displayColor: textColor,
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
          labelStyle: const TextStyle(color: textColor),
          floatingLabelStyle: const TextStyle(color: textColor),
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

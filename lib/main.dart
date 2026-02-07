import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'screens/about_screen.dart';
import 'screens/add_entry_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'theme/app_colors.dart';

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
    // Single typography scale for the whole app.
    const textSizeXSmall = 13.0;
    const textSizeSmall = 15.0;
    const textSizeMedium = 17.0;
    const textSizeLarge = 23.0;

    final baseTextTheme = ThemeData.dark().textTheme.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
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
    final buttonBaseHsl = HSLColor.fromColor(AppColors.buttonBackground);
    final buttonBorderColor = buttonBaseHsl
        .withLightness((buttonBaseHsl.lightness + 0.12).clamp(0.0, 1.0))
        .toColor();
    final borderBaseHsl = HSLColor.fromColor(AppColors.border);
    final disabledButtonBorderColor = borderBaseHsl
        .withLightness((borderBaseHsl.lightness + 0.12).clamp(0.0, 1.0))
        .toColor();

    return MaterialApp(
      title: 'Calorie Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.buttonBackground,
          brightness: Brightness.dark,
        )
            .copyWith(
              primary: AppColors.buttonBackground,
              onPrimary: AppColors.buttonForeground,
              surface: AppColors.boxBackground,
              surfaceContainerHighest: AppColors.boxBackground,
              onSurface: AppColors.text,
              onSurfaceVariant: AppColors.text,
              outline: AppColors.border,
            ),
        scaffoldBackgroundColor: AppColors.pageBackground,
        cardTheme: const CardThemeData(
          color: AppColors.boxBackground,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
        ),
        textTheme: appTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.boxBackground,
          foregroundColor: AppColors.text,
          centerTitle: true,
          titleTextStyle: appTextTheme.titleLarge?.copyWith(
            color: AppColors.text,
            fontSize: textSizeLarge,
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.boxBackground,
          textStyle: appTextTheme.bodyMedium?.copyWith(
            fontSize: textSizeMedium,
            color: AppColors.text,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.border, width: 2),
          ),
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.border),
          ),
          labelStyle: appTextTheme.bodyLarge?.copyWith(
            color: AppColors.text,
            fontSize: textSizeMedium,
          ),
          floatingLabelStyle: appTextTheme.bodyLarge?.copyWith(
            color: AppColors.text,
            fontSize: textSizeMedium,
          ),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.text,
          selectionHandleColor: AppColors.text,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.buttonBackground,
            foregroundColor: AppColors.buttonForeground,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: appTextTheme.labelLarge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ).copyWith(
            side: WidgetStateProperty.resolveWith<BorderSide>((states) {
              if (states.contains(WidgetState.disabled)) {
                return BorderSide(color: disabledButtonBorderColor, width: 1);
              }
              return BorderSide(color: buttonBorderColor, width: 1);
            }),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.buttonBackground,
          foregroundColor: AppColors.buttonForeground,
        ).copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: buttonBorderColor,
              width: 1,
            ),
          ),
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

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'screens/about_screen.dart';
import 'screens/add_entry_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'services/update_coordinator.dart';
import 'theme/app_colors.dart';
import 'theme/ui_constants.dart';
import 'widgets/app_dialog.dart';
import 'widgets/dialog_action_row.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.initialize();
  await SettingsService.instance.initialize();
  runApp(const CalorieTrackerApp());
}

class CalorieTrackerApp extends StatefulWidget {
  const CalorieTrackerApp({super.key});

  @override
  State<CalorieTrackerApp> createState() => _CalorieTrackerAppState();
}

class _CalorieTrackerAppState extends State<CalorieTrackerApp> {
  bool _startupUpdateCheckScheduled = false;

  Locale? _resolveLocale(String languageCode) {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == languageCode) {
        return locale;
      }
    }
    return AppLocalizations.supportedLocales.first;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startupUpdateCheckScheduled) {
      return;
    }
    _startupUpdateCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupUpdateCheck();
    });
  }

  Future<void> _runStartupUpdateCheck() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final result = await UpdateCoordinator.instance.checkForUpdates(
        currentVersion: packageInfo.version,
      );
      if (!mounted || !result.updateAvailable) {
        return;
      }
      final popupContext = navigatorKey.currentContext;
      if (popupContext == null || !popupContext.mounted) {
        return;
      }
      final l10n = AppLocalizations.of(popupContext)!;
      final openAbout = await showDialog<bool>(
            context: popupContext,
            builder: (dialogContext) {
              return AppDialog(
                title: Text(l10n.updateAvailableDialogTitle),
                content: Text(
                  l10n.updateAvailableDialogBody(
                    result.latestVersion,
                  ),
                ),
                actionItems: [
                  DialogActionItem(
                    width: UiConstants.buttonMinWidth,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(l10n.updateAvailableDialogLater),
                    ),
                  ),
                  DialogActionItem(
                    width: UiConstants.buttonMinWidth,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      icon: const Icon(Icons.info_outline),
                      label: Text(l10n.updateAvailableDialogView),
                    ),
                  ),
                ],
              );
            },
          ) ??
          false;
      if (!mounted || !openAbout) {
        return;
      }
      await navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => AboutScreen(initialUpdateResult: result),
        ),
      );
    } catch (error, stackTrace) {
      // Startup update check is best-effort and should stay silent to users.
      debugPrint('Startup update check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = SettingsService.instance;
    final baseTextTheme = ThemeData.dark().textTheme.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        );
    final appTextTheme = baseTextTheme.copyWith(
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: UiConstants.textLarge,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: UiConstants.textLarge,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: UiConstants.textMedium,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: UiConstants.textSmall,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: UiConstants.textMedium,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: UiConstants.textSmall,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: UiConstants.textXSmall,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: UiConstants.textSmall,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: UiConstants.textXSmall,
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

    return AnimatedBuilder(
      animation: settingsService,
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        locale: _resolveLocale(settingsService.settings.languageCode),
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
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
            borderRadius: BorderRadius.all(Radius.circular(UiConstants.cornerRadius)),
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
            fontSize: UiConstants.textLarge,
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.boxBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          textStyle: appTextTheme.bodyMedium?.copyWith(
            fontSize: UiConstants.textMedium,
            color: AppColors.text,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
            borderSide: const BorderSide(color: AppColors.border, width: 2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          labelStyle: appTextTheme.bodyLarge?.copyWith(
            color: AppColors.text,
            fontSize: UiConstants.textMedium,
          ),
          floatingLabelStyle: appTextTheme.bodyLarge?.copyWith(
            color: AppColors.text,
            fontSize: UiConstants.textMedium,
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
            padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
            textStyle: appTextTheme.labelLarge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
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
            borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
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
      navigatorObservers: [routeObserver],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}

String formatDate(DateTime date, {String? languageCode}) {
  final resolvedLanguageCode = languageCode ?? SettingsService.instance.settings.languageCode;
  return DateFormat.yMMMMd(resolvedLanguageCode).format(date);
}

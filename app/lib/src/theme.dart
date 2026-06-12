import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Tokens — fuente de verdad para el theme. Todos los valores vienen de
// DESIGN.md front-matter; ningún widget usa Color(...) hardcodeado.
const _bg = Color(0xFF0D1117);
const _surface = Color(0xFF161B22);
const _surfaceRaised = Color(0xFF21262D);
const _surfaceTint = Color(0xFF2A2F38);
const _primary = Color(0xFF39D2C0);
const _onPrimary = Color(0xFF0D1117);
const _primaryContainer = Color(0xFF0D3330);
const _onPrimaryContainer = Color(0xFF4FE5D3);
const _secondary = Color(0xFFF8A051);
const _onSecondary = Color(0xFF0D1117);
const _secondaryContainer = Color(0xFF3D2000);
const _text = Color(0xFFE6EDF3);
const _textMuted = Color(0xFF8B949E);
const _border = Color(0xFF30363D);
const _error = Color(0xFFF85149);
const _errorContainer = Color(0xFF2E0D0D);

ThemeData buildLifeosTheme() {
  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _primary,
    onPrimary: _onPrimary,
    primaryContainer: _primaryContainer,
    onPrimaryContainer: _onPrimaryContainer,
    secondary: _secondary,
    onSecondary: _onSecondary,
    secondaryContainer: _secondaryContainer,
    onSecondaryContainer: _secondary,
    tertiary: const Color(0xFF58A6FF),
    onTertiary: _onPrimary,
    error: _error,
    onError: _onPrimary,
    errorContainer: _errorContainer,
    onErrorContainer: _error,
    surface: _bg,
    onSurface: _text,
    onSurfaceVariant: _textMuted,
    surfaceContainerLowest: _bg,
    surfaceContainerLow: _surface,
    surfaceContainer: _surface,
    surfaceContainerHigh: _surfaceRaised,
    surfaceContainerHighest: _surfaceTint,
    outline: _border,
    outlineVariant: _surfaceTint,
    inverseSurface: _text,
    onInverseSurface: _bg,
    inversePrimary: _primaryContainer,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: _primary,
  );

  final textTheme = _buildTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: _bg,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: _bg,
      foregroundColor: _text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: _text),
    ),
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _error, width: 2),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(color: _textMuted),
      floatingLabelStyle: textTheme.labelSmall?.copyWith(color: _primary),
      helperStyle: textTheme.labelSmall?.copyWith(color: _textMuted),
      hintStyle: textTheme.bodyMedium?.copyWith(color: _textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: _onPrimary,
        minimumSize: const Size(88, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _text,
        side: const BorderSide(color: _border),
        minimumSize: const Size(88, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primary,
        minimumSize: const Size(88, 48),
        textStyle: textTheme.labelLarge,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _primary,
      foregroundColor: _onPrimary,
      elevation: 3,
      shape: CircleBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _surface,
      indicatorColor: _primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _onPrimaryContainer);
        }
        return const IconThemeData(color: _textMuted);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final base = textTheme.labelSmall ?? const TextStyle();
        if (states.contains(WidgetState.selected)) {
          return base.copyWith(color: _onPrimaryContainer);
        }
        return base.copyWith(color: _textMuted);
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _surfaceRaised,
      modalBackgroundColor: _surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _surfaceRaised,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: _text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(
      color: _border,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: _text,
      iconColor: _textMuted,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: _textMuted,
      collapsedIconColor: _textMuted,
      textColor: _primary,
      collapsedTextColor: _text,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _surfaceTint,
      selectedColor: _primaryContainer,
      labelStyle: textTheme.labelSmall?.copyWith(color: _text),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: _surface,
        foregroundColor: _textMuted,
        selectedForegroundColor: _primary,
        selectedBackgroundColor: _primaryContainer,
        side: const BorderSide(color: _border),
      ),
    ),
  );
}

TextTheme _buildTextTheme() {
  return TextTheme(
    // DM Mono para la cifra hero — la única variante sans en el theme.
    displaySmall: GoogleFonts.dmMono(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.1,
    ),
    headlineMedium: GoogleFonts.dmSans(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    titleLarge: GoogleFonts.dmSans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    titleMedium: GoogleFonts.dmSans(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: GoogleFonts.dmSans(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.dmSans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    labelLarge: GoogleFonts.dmSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    labelSmall: GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.2,
      letterSpacing: 0.66,
    ),
  );
}

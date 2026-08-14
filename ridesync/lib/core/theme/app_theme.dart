import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// RideSync design system.
///
/// Dark-first: the primary surface is a live map, often used at night and for
/// hours at a time. Dark surfaces reduce glare on a night ride and cut battery
/// draw on OLED panels — which matters when GPS and sensors are already running.
///
/// Colour discipline is the core rule of this system:
///   - The interface is near-monochrome. Colour means status, never decoration.
///   - [AppColors.emergency] appears in exactly two places: the crash countdown
///     and SOS. Nowhere else. Ever.
///   - Validation and warnings use [AppColors.warning] (amber), which is also
///     wired to `colorScheme.error` so Flutter's automatic error states never
///     borrow the emergency red.
///   - Active/tracking state is teal, not green. Roughly 8% of men have
///     red-green colour vision deficiency, for whom a green "safe" state and a
///     red "emergency" state converge. Teal stays separable under all common
///     CVD types. Colour never carries meaning alone — always pair with an icon
///     and a text label.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Neutral base — carries ~95% of the interface
  // ---------------------------------------------------------------------------

  /// Page canvas. The darkest surface.
  static const Color void_ = Color(0xFF0B0D0E);

  /// Cards, sheets, elevated panels sitting on [void_].
  static const Color slate = Color(0xFF16191B);

  /// Inputs, chips, pressed states. One step above [slate].
  static const Color graphite = Color(0xFF24282B);

  /// Hairline borders and dividers.
  static const Color border = Color(0xFF2E3336);

  /// Secondary text, inactive icons, offline member markers.
  static const Color ash = Color(0xFF6B7478);

  /// Muted helper text, timestamps, metadata.
  static const Color smoke = Color(0xFF9BA1A4);

  /// Primary text on dark surfaces.
  static const Color fog = Color(0xFFE8EAEB);

  /// Pure white. Use sparingly — reserved for text on [emergency].
  static const Color paper = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // State colours — status only, never decoration
  // ---------------------------------------------------------------------------

  /// Active trip, live tracking, member moving, primary actions.
  static const Color signal = Color(0xFF00B39F);

  /// Darker teal for pressed states and text on light teal fills.
  static const Color signalDeep = Color(0xFF00332D);

  /// Warnings, validation errors, low-confidence events, degraded GPS.
  /// This is also `colorScheme.error` — see the class doc for why.
  static const Color warning = Color(0xFFE8960C);

  /// Member stopped but online.
  static const Color stopped = Color(0xFF8D9296);

  // ---------------------------------------------------------------------------
  // RESERVED — crash countdown and SOS only
  // ---------------------------------------------------------------------------

  /// Do not use this for errors, destructive actions, delete buttons, or
  /// anything else. If red appears on ordinary UI, it stops reading as urgent
  /// at the one moment that matters.
  static const Color emergency = Color(0xFFE5342A);

  /// Pressed state for emergency controls.
  static const Color emergencyDeep = Color(0xFFB8241C);

  /// Tinted background for emergency banners and countdown surfaces.
  static const Color emergencyWash = Color(0xFF2A0F0D);
}

/// Spacing scale. Use these instead of literal numbers so density can be tuned
/// in one place later.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 6;
  static const double card = 12;
  static const double button = 12;

  /// Pills — filter chips, status badges, the SOS button.
  static const double pill = 999;
}

/// Motion durations.
abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 400);
}

abstract final class AppTheme {
  /// Base text theme.
  ///
  /// Weights sit at 500–700 for anything actionable. Thin display weights read
  /// beautifully on a desktop hero image and fail completely on a phone held at
  /// arm's length, in sunlight, at speed. Every string in this app may need to
  /// be read in exactly those conditions.
  static TextTheme _textTheme() {
    final base = GoogleFonts.interTextTheme();

    return base.copyWith(
      // Large numerals — speed readouts, countdown timer.
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: -1.5,
        color: AppColors.fog,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -1.0,
        color: AppColors.fog,
      ),
      // Screen titles.
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.5,
        color: AppColors.fog,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.3,
        color: AppColors.fog,
      ),
      // Card titles, member names.
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.fog,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.fog,
      ),
      // Body copy.
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.fog,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.smoke,
      ),
      // Timestamps, metadata, helper text.
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.ash,
      ),
      // Button labels.
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.1,
      ),
      // Overlines, section labels.
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.6,
        color: AppColors.ash,
      ),
    );
  }

  static ThemeData get dark {
    final textTheme = _textTheme();

    const colorScheme = ColorScheme.dark(
      primary: AppColors.signal,
      onPrimary: AppColors.signalDeep,
      primaryContainer: AppColors.signalDeep,
      onPrimaryContainer: AppColors.signal,

      secondary: AppColors.graphite,
      onSecondary: AppColors.fog,

      // Amber, not red. Flutter routes form validation and TextField error
      // states through this — the emergency red must never be reachable
      // automatically.
      error: AppColors.warning,
      onError: AppColors.void_,

      surface: AppColors.void_,
      onSurface: AppColors.fog,
      surfaceContainerHighest: AppColors.graphite,
      onSurfaceVariant: AppColors.smoke,

      outline: AppColors.border,
      outlineVariant: AppColors.graphite,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.void_,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.void_,
        foregroundColor: AppColors.fog,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Primary actions are filled and unmistakable. Ghost buttons look elegant
      // and are the wrong choice for an app where finding the right control
      // quickly can matter.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.signal,
          foregroundColor: AppColors.signalDeep,
          disabledBackgroundColor: AppColors.graphite,
          disabledForegroundColor: AppColors.ash,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.fog,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.signal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.slate,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.ash),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.smoke),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.signal,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.warning),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.signal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.warning),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.warning, width: 1.5),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.slate,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.slate,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.card * 1.5),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.graphite,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.fog),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.graphite,
        selectedColor: AppColors.signal,
        labelStyle: textTheme.titleSmall,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.signal,
        linearTrackColor: AppColors.graphite,
      ),

      iconTheme: const IconThemeData(color: AppColors.fog, size: 22),

      listTileTheme: ListTileThemeData(
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
        iconColor: AppColors.smoke,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
    );
  }

  /// Styling for emergency controls.
  ///
  /// Deliberately not part of [dark] — it must be reached for explicitly, so
  /// nobody applies it by accident. Use only on the SOS button and the crash
  /// countdown's confirm control.
  static ButtonStyle emergencyButtonStyle(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.emergency,
      foregroundColor: AppColors.paper,
      disabledBackgroundColor: AppColors.emergencyDeep,
      elevation: 0,
      minimumSize: const Size(double.infinity, 64),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

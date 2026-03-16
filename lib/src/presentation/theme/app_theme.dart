import 'package:flutter/material.dart';

import '../../models/chat_settings.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light(AppColorPalette palette) {
    return _buildTheme(palette: palette, brightness: Brightness.light);
  }

  static ThemeData dark(AppColorPalette palette) {
    return _buildTheme(palette: palette, brightness: Brightness.dark);
  }

  static String paletteLabel(AppColorPalette palette) {
    switch (palette) {
      case AppColorPalette.ocean:
        return 'Океан';
      case AppColorPalette.sunset:
        return 'Закат';
      case AppColorPalette.forest:
        return 'Лес';
    }
  }

  static String modeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'Система';
      case AppThemeMode.light:
        return 'Светлая';
      case AppThemeMode.dark:
        return 'Темная';
    }
  }

  static ThemeData _buildTheme({
    required AppColorPalette palette,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final spec = _paletteSpec(palette);
    final scheme = ColorScheme.fromSeed(
      seedColor: spec.seed,
      brightness: brightness,
    );

    final chatTheme = ChatThemeExtension(
      backgroundGradient: isDark ? spec.darkGradient : spec.lightGradient,
      overlayGradient: isDark
          ? const [Color(0x6610182A), Color(0x33111825)]
          : const [Color(0x44FFFFFF), Color(0x11FFFFFF)],
      userBubbleColor: isDark ? spec.darkUserBubble : spec.lightUserBubble,
      assistantBubbleColor: isDark
          ? spec.darkAssistantBubble
          : spec.lightAssistantBubble,
      panelColor: isDark ? const Color(0xA6141B2A) : const Color(0xD9FFFFFF),
      panelBorderColor: isDark
          ? const Color(0x3DF2F5FF)
          : const Color(0x2B17243A),
      accentSoft: scheme.primary.withValues(alpha: 0.18),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[chatTheme],
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final textTheme = _buildTextTheme(base.textTheme, scheme);
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C2432) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0x8A131A28) : const Color(0xCCFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, ColorScheme scheme) {
    return base.copyWith(
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.15,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.12,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.42,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.42,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.25,
      ),
    );
  }

  static _PaletteSpec _paletteSpec(AppColorPalette palette) {
    switch (palette) {
      case AppColorPalette.ocean:
        return const _PaletteSpec(
          seed: Color(0xFF1E6DF8),
          lightGradient: [
            Color(0xFFF2F7FF),
            Color(0xFFE6F7FF),
            Color(0xFFF4ECFF),
          ],
          darkGradient: [
            Color(0xFF0A1220),
            Color(0xFF101A2D),
            Color(0xFF151632),
          ],
          lightUserBubble: Color(0xFFDCEAFF),
          darkUserBubble: Color(0xFF1A2F55),
          lightAssistantBubble: Color(0xFFFFFFFF),
          darkAssistantBubble: Color(0xFF162033),
        );
      case AppColorPalette.sunset:
        return const _PaletteSpec(
          seed: Color(0xFFE56B5B),
          lightGradient: [
            Color(0xFFFFF2EA),
            Color(0xFFFFE4E0),
            Color(0xFFFFF4DB),
          ],
          darkGradient: [
            Color(0xFF22110F),
            Color(0xFF311614),
            Color(0xFF2A1D13),
          ],
          lightUserBubble: Color(0xFFFFE3D8),
          darkUserBubble: Color(0xFF5A2822),
          lightAssistantBubble: Color(0xFFFFFDFC),
          darkAssistantBubble: Color(0xFF2F1C1A),
        );
      case AppColorPalette.forest:
        return const _PaletteSpec(
          seed: Color(0xFF2B9F78),
          lightGradient: [
            Color(0xFFEEFBF4),
            Color(0xFFE4F7EF),
            Color(0xFFF2FBEA),
          ],
          darkGradient: [
            Color(0xFF0E1C19),
            Color(0xFF142724),
            Color(0xFF1A2C22),
          ],
          lightUserBubble: Color(0xFFD8F2E5),
          darkUserBubble: Color(0xFF1D4D3D),
          lightAssistantBubble: Color(0xFFFFFFFF),
          darkAssistantBubble: Color(0xFF1A2E28),
        );
    }
  }
}

class _PaletteSpec {
  const _PaletteSpec({
    required this.seed,
    required this.lightGradient,
    required this.darkGradient,
    required this.lightUserBubble,
    required this.darkUserBubble,
    required this.lightAssistantBubble,
    required this.darkAssistantBubble,
  });

  final Color seed;
  final List<Color> lightGradient;
  final List<Color> darkGradient;
  final Color lightUserBubble;
  final Color darkUserBubble;
  final Color lightAssistantBubble;
  final Color darkAssistantBubble;
}

@immutable
class ChatThemeExtension extends ThemeExtension<ChatThemeExtension> {
  const ChatThemeExtension({
    required this.backgroundGradient,
    required this.overlayGradient,
    required this.userBubbleColor,
    required this.assistantBubbleColor,
    required this.panelColor,
    required this.panelBorderColor,
    required this.accentSoft,
  });

  final List<Color> backgroundGradient;
  final List<Color> overlayGradient;
  final Color userBubbleColor;
  final Color assistantBubbleColor;
  final Color panelColor;
  final Color panelBorderColor;
  final Color accentSoft;

  @override
  ChatThemeExtension copyWith({
    List<Color>? backgroundGradient,
    List<Color>? overlayGradient,
    Color? userBubbleColor,
    Color? assistantBubbleColor,
    Color? panelColor,
    Color? panelBorderColor,
    Color? accentSoft,
  }) {
    return ChatThemeExtension(
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      overlayGradient: overlayGradient ?? this.overlayGradient,
      userBubbleColor: userBubbleColor ?? this.userBubbleColor,
      assistantBubbleColor: assistantBubbleColor ?? this.assistantBubbleColor,
      panelColor: panelColor ?? this.panelColor,
      panelBorderColor: panelBorderColor ?? this.panelBorderColor,
      accentSoft: accentSoft ?? this.accentSoft,
    );
  }

  @override
  ChatThemeExtension lerp(ThemeExtension<ChatThemeExtension>? other, double t) {
    if (other is! ChatThemeExtension) {
      return this;
    }
    return ChatThemeExtension(
      backgroundGradient: _lerpList(
        backgroundGradient,
        other.backgroundGradient,
        t,
      ),
      overlayGradient: _lerpList(overlayGradient, other.overlayGradient, t),
      userBubbleColor: Color.lerp(userBubbleColor, other.userBubbleColor, t)!,
      assistantBubbleColor: Color.lerp(
        assistantBubbleColor,
        other.assistantBubbleColor,
        t,
      )!,
      panelColor: Color.lerp(panelColor, other.panelColor, t)!,
      panelBorderColor: Color.lerp(
        panelBorderColor,
        other.panelBorderColor,
        t,
      )!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
    );
  }

  static List<Color> _lerpList(List<Color> a, List<Color> b, double t) {
    final length = a.length < b.length ? a.length : b.length;
    return List<Color>.generate(
      length,
      (index) => Color.lerp(a[index], b[index], t)!,
      growable: false,
    );
  }
}

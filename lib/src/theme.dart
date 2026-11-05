// PaystraterTheme: the same variable names as the web's Appearance API, with
// the Paystrater design from the landing page and app refresh as the default:
// bordered, rounded panels with no shadows, #285BB6 in light mode and #A2AED1
// with ink text in dark mode.
import 'package:flutter/widgets.dart';

enum PaystraterThemeMode { light, dark, auto }

class PaystraterTheme {
  const PaystraterTheme({
    required this.colorBackground,
    required this.colorSurface,
    required this.colorText,
    required this.colorTextBody,
    required this.colorTextMuted,
    required this.colorBorder,
    required this.colorPrimary,
    required this.colorPrimaryHover,
    required this.colorOnPrimary,
    required this.colorPrimaryText,
    required this.colorPrimarySoft,
    required this.colorSuccess,
    required this.colorWarning,
    required this.colorDanger,
    this.fontFamily,
    this.fontFamilyMono,
    this.borderRadius = 8,
    this.borderRadiusSurface = 12,
  });

  static const light = PaystraterTheme(
    colorBackground: Color(0xFFFFFFFF),
    colorSurface: Color(0xFFF4F4F1),
    colorText: Color(0xFF111318),
    colorTextBody: Color(0xFF3A3F4A),
    colorTextMuted: Color(0xFF636975),
    colorBorder: Color(0xFFE2E2DD),
    colorPrimary: Color(0xFF285BB6),
    colorPrimaryHover: Color(0xFF1D4693),
    colorOnPrimary: Color(0xFFFFFFFF),
    colorPrimaryText: Color(0xFF285BB6),
    colorPrimarySoft: Color(0xFFEAF1FC),
    colorSuccess: Color(0xFF047857),
    colorWarning: Color(0xFFB45309),
    colorDanger: Color(0xFFC41E3A),
  );

  static const dark = PaystraterTheme(
    colorBackground: Color(0xFF0C0D10),
    colorSurface: Color(0xFF1C1E24),
    colorText: Color(0xFFF2F3F5),
    colorTextBody: Color(0xFFC4C8D0),
    colorTextMuted: Color(0xFF8E94A0),
    colorBorder: Color(0xFF272931),
    // Filled buttons are the periwinkle from the landing page and app with ink text: 8.5:1
    colorPrimary: Color(0xFFA2AED1),
    colorPrimaryHover: Color(0xFFB8C3E0),
    colorOnPrimary: Color(0xFF0A1224),
    colorPrimaryText: Color(0xFFA2AED1),
    colorPrimarySoft: Color(0xFF182136),
    colorSuccess: Color(0xFF4ADEA0),
    colorWarning: Color(0xFFFBBF24),
    colorDanger: Color(0xFFF87185),
  );

  /// The theme for a mode; auto follows the platform's brightness.
  static PaystraterTheme of(PaystraterThemeMode mode, Brightness platform) {
    if (mode == PaystraterThemeMode.dark ||
        (mode == PaystraterThemeMode.auto && platform == Brightness.dark)) {
      return dark;
    }
    return light;
  }

  final Color colorBackground;
  final Color colorSurface;
  final Color colorText;
  final Color colorTextBody;
  final Color colorTextMuted;
  final Color colorBorder;
  final Color colorPrimary;
  final Color colorPrimaryHover;
  final Color colorOnPrimary;
  final Color colorPrimaryText;
  final Color colorPrimarySoft;
  final Color colorSuccess;
  final Color colorWarning;
  final Color colorDanger;

  /// A font your app ships; the SDK never loads fonts, so null means the system font.
  final String? fontFamily;
  final String? fontFamilyMono;
  final double borderRadius;
  final double borderRadiusSurface;

  PaystraterTheme copyWith({
    Color? colorBackground,
    Color? colorSurface,
    Color? colorText,
    Color? colorTextBody,
    Color? colorTextMuted,
    Color? colorBorder,
    Color? colorPrimary,
    Color? colorPrimaryHover,
    Color? colorOnPrimary,
    Color? colorPrimaryText,
    Color? colorPrimarySoft,
    Color? colorSuccess,
    Color? colorWarning,
    Color? colorDanger,
    String? fontFamily,
    String? fontFamilyMono,
    double? borderRadius,
    double? borderRadiusSurface,
  }) =>
      PaystraterTheme(
        colorBackground: colorBackground ?? this.colorBackground,
        colorSurface: colorSurface ?? this.colorSurface,
        colorText: colorText ?? this.colorText,
        colorTextBody: colorTextBody ?? this.colorTextBody,
        colorTextMuted: colorTextMuted ?? this.colorTextMuted,
        colorBorder: colorBorder ?? this.colorBorder,
        colorPrimary: colorPrimary ?? this.colorPrimary,
        colorPrimaryHover: colorPrimaryHover ?? this.colorPrimaryHover,
        colorOnPrimary: colorOnPrimary ?? this.colorOnPrimary,
        colorPrimaryText: colorPrimaryText ?? this.colorPrimaryText,
        colorPrimarySoft: colorPrimarySoft ?? this.colorPrimarySoft,
        colorSuccess: colorSuccess ?? this.colorSuccess,
        colorWarning: colorWarning ?? this.colorWarning,
        colorDanger: colorDanger ?? this.colorDanger,
        fontFamily: fontFamily ?? this.fontFamily,
        fontFamilyMono: fontFamilyMono ?? this.fontFamilyMono,
        borderRadius: borderRadius ?? this.borderRadius,
        borderRadiusSurface: borderRadiusSurface ?? this.borderRadiusSurface,
      );
}

/// WCAG contrast ratio of two colours (6.7: accessibility is not themeable away).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Pairs under WCAG AA (4.5:1); the widget prints them in test mode.
List<String> contrastWarnings(PaystraterTheme t) {
  final pairs = <String, List<Color>>{
    'Text': [t.colorText, t.colorBackground],
    'Body text': [t.colorTextBody, t.colorBackground],
    'Muted text': [t.colorTextMuted, t.colorBackground],
    'Button text': [t.colorOnPrimary, t.colorPrimary],
    'Links': [t.colorPrimaryText, t.colorBackground],
    'Error text': [t.colorDanger, t.colorBackground],
  };
  return [
    for (final e in pairs.entries)
      if (contrastRatio(e.value[0], e.value[1]) < 4.5)
        '${e.key} has a contrast of ${contrastRatio(e.value[0], e.value[1]).toStringAsFixed(2)}:1, under WCAG AA (4.5:1).',
  ];
}

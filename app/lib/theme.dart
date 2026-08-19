import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Nocturne — the design-system tokens from the asb mockup, as a swappable
/// palette. Three themes ship (Nocturne / Dim / Daylight); `system` picks
/// Nocturne or Daylight from the platform brightness.
@immutable
class Palette {
  final Brightness brightness;
  final Color bg, surface, text, divider, accent;
  final Color n200, n300, n400, n500, n600, n700, n800, n900;
  final Color a200, a300, a400, a500, a600, a700, a900;
  final Color band, well, lock, pos, neg, posBg, negBg;

  const Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.text,
    required this.divider,
    required this.accent,
    required this.n200,
    required this.n300,
    required this.n400,
    required this.n500,
    required this.n600,
    required this.n700,
    required this.n800,
    required this.n900,
    required this.a200,
    required this.a300,
    required this.a400,
    required this.a500,
    required this.a600,
    required this.a700,
    required this.a900,
    required this.band,
    required this.well,
    required this.lock,
    required this.pos,
    required this.neg,
    required this.posBg,
    required this.negBg,
  });

  static const nocturne = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF161826),
    surface: Color(0xFF232532),
    text: Color(0xFFE9E9ED),
    divider: Color(0x1FE9E9ED),
    accent: Color(0xFF9184D9),
    n200: Color(0xFFCFD3E5),
    n300: Color(0xFFB9BDD2),
    n400: Color(0xFFA4A8BD),
    n500: Color(0xFF9397AB),
    n600: Color(0xFF75798C),
    n700: Color(0xFF6C7083),
    n800: Color(0xFF3A3D4D),
    n900: Color(0xFF262838),
    a200: Color(0xFFD2CEFD),
    a300: Color(0xFFB8B1EC),
    a400: Color(0xFFA396E2),
    a500: Color(0xFF9184D9),
    a600: Color(0xFF7C6DCF),
    a700: Color(0xFF4B4278),
    a900: Color(0xFF262341),
    band: Color(0xFF1C1E2B),
    well: Color(0xFF101220),
    lock: Color(0xFF101220),
    pos: Color(0xFF6FB98A),
    neg: Color(0xFFD1706A),
    posBg: Color(0x1F6FB98A),
    negBg: Color(0x21D1706A),
  );

  static const dim = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF23252F),
    surface: Color(0xFF2D303C),
    text: Color(0xFFE3E4EA),
    divider: Color(0x21E3E4EA),
    accent: Color(0xFFA79CE4),
    n200: Color(0xFFC9CBD7),
    n300: Color(0xFFB2B5C3),
    n400: Color(0xFF9FA2B1),
    n500: Color(0xFF8E91A2),
    n600: Color(0xFF767989),
    n700: Color(0xFF737686),
    n800: Color(0xFF464958),
    n900: Color(0xFF343745),
    a200: Color(0xFFDCD8FC),
    a300: Color(0xFFC5BEF2),
    a400: Color(0xFFB3A9E9),
    a500: Color(0xFFA79CE4),
    a600: Color(0xFF9689DC),
    a700: Color(0xFF575086),
    a900: Color(0xFF353252),
    band: Color(0xFF292C37),
    well: Color(0xFF1B1D26),
    lock: Color(0xFF1B1D26),
    pos: Color(0xFF7CC296),
    neg: Color(0xFFDA8078),
    posBg: Color(0x217CC296),
    negBg: Color(0x24DA8078),
  );

  static const daylight = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFF2F1F7),
    surface: Color(0xFFF9F9FC),
    text: Color(0xFF1B1C27),
    divider: Color(0x241B1C27),
    accent: Color(0xFF6455BD),
    n200: Color(0xFF33354A),
    n300: Color(0xFF494B60),
    n400: Color(0xFF5C5E72),
    n500: Color(0xFF6D6F82),
    n600: Color(0xFF7F8194),
    n700: Color(0xFF8F91A3),
    n800: Color(0xFFC9C7D6),
    n900: Color(0xFFE7E6EF),
    a200: Color(0xFF3B3190),
    a300: Color(0xFF4A3FA4),
    a400: Color(0xFF5748B2),
    a500: Color(0xFF6455BD),
    a600: Color(0xFF7466C6),
    a700: Color(0xFFC3BDEE),
    a900: Color(0xFFEBE9FA),
    band: Color(0xFFEAE9F2),
    well: Color(0xFFE7E6EF),
    lock: Color(0xFFE2E0EC),
    pos: Color(0xFF2F7A4A),
    neg: Color(0xFFB03A2B),
    posBg: Color(0x1C2F7A4A),
    negBg: Color(0x1AB03A2B),
  );
}

enum ThemeChoice { system, nocturne, dim, daylight }

extension ThemeChoiceX on ThemeChoice {
  String get label => switch (this) {
        ThemeChoice.system => 'Follow the system',
        ThemeChoice.nocturne => 'Nocturne',
        ThemeChoice.dim => 'Dim',
        ThemeChoice.daylight => 'Daylight',
      };

  String hint(bool sysDark) => switch (this) {
        ThemeChoice.system =>
          sysDark ? 'currently dark → Nocturne' : 'currently light → Daylight',
        ThemeChoice.nocturne => 'the near-black ground',
        ThemeChoice.dim => 'lifted, softer contrast',
        ThemeChoice.daylight => 'paper and ink',
      };

  Palette resolve(bool sysDark) => switch (this) {
        ThemeChoice.system => sysDark ? Palette.nocturne : Palette.daylight,
        ThemeChoice.nocturne => Palette.nocturne,
        ThemeChoice.dim => Palette.dim,
        ThemeChoice.daylight => Palette.daylight,
      };
}

/// Inherited palette so any widget can read `context.p`.
class PaletteScope extends InheritedWidget {
  final Palette palette;
  const PaletteScope({super.key, required this.palette, required super.child});

  static Palette of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<PaletteScope>()!.palette;

  @override
  bool updateShouldNotify(PaletteScope old) => old.palette != palette;
}

extension PaletteContext on BuildContext {
  Palette get p => PaletteScope.of(this);
}

/// Type helpers. `ui` = Inter (body + heading), `mono` = the code face.
TextStyle ui(
  double size, {
  FontWeight weight = FontWeight.w400,
  required Color color,
  double? height,
  double? spacing,
  TextDecoration? decoration,
}) =>
    GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: spacing,
      decoration: decoration,
      decorationColor: color,
    );

TextStyle mono(
  double size, {
  FontWeight weight = FontWeight.w400,
  required Color color,
  double? height,
  double? spacing,
}) =>
    GoogleFonts.robotoMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: spacing,
    );

/// `hex[..8]…hex[-4..]` — the short node-id form the mockup uses everywhere.
String shortHex(String hex) =>
    hex.length <= 12 ? hex : '${hex.substring(0, 8)}…${hex.substring(hex.length - 4)}';

import 'package:flutter/material.dart';

/// One field per CSS custom property in docs/design-02/assets/tokens.css.
/// Design-02 is locked: change values only via a flagged proposal.
@immutable
class WeaveTokens extends ThemeExtension<WeaveTokens> {
  const WeaveTokens({
    required this.ground,
    required this.surface,
    required this.raised,
    required this.hover,
    required this.border,
    required this.rule,
    required this.control,
    required this.text,
    required this.muted,
    required this.faint,
    required this.primary,
    required this.onPrimary,
    required this.negative,
    required this.positive,
    required this.pillNeutralBg,
    required this.pillNeutralInk,
    required this.pillNegativeBg,
    required this.pillNegativeInk,
    required this.floatShadow,
    required this.paperMix,
  });

  // ---- Mode-specific ----
  final Color ground; // --ground
  final Color surface; // --surface
  final Color raised; // --raised
  final Color hover; // --hover
  final Color border; // --border
  final Color rule; // --rule
  final Color control; // --control
  final Color text; // --text
  final Color muted; // --muted
  final Color faint; // --faint
  final Color primary; // --primary
  final Color onPrimary; // --on-primary
  final Color negative; // --negative
  final Color positive; // --positive
  final Color pillNeutralBg; // --pill-neutral-bg
  final Color pillNeutralInk; // --pill-neutral-ink
  final Color pillNegativeBg; // --pill-negative-bg
  final Color pillNegativeInk; // --pill-negative-ink
  final List<BoxShadow> floatShadow; // --float-shadow
  final double paperMix; // --paper-mix (22% / 16%)

  // ---- Shared ----
  String get font => 'Geist'; // --font (fallbacks in [fontFallback])
  List<String> get fontFallback => const ['Inter', 'system-ui']; // --font

  double get radiusCard => 8; // --radius-card
  double get radiusControl => 6; // --radius-control
  double get radiusChip => 4; // --radius-chip
  double get gap => 12; // --gap
  double get pad => 24; // --pad
  double get rowHeight => 44; // --row-height
  double get controlHeight => 36; // --control-height
  double get sidebarWidth => 256; // --sidebar-width

  double get fsTitle => 24; // --fs-title
  double get fsSection => 16; // --fs-section
  double get fsFigure => 30; // --fs-figure
  double get fsBody => 14; // --fs-body
  double get fsSmall => 13; // --fs-small

  Duration get durFast => const Duration(milliseconds: 120); // --dur-fast
  Duration get dur => const Duration(milliseconds: 180); // --dur
  Curve get easeOut => const Cubic(.23, 1, .32, 1); // --ease-out
  Curve get easeSheet => const Cubic(.32, .72, 0, 1); // --ease-sheet
  Curve get ease => easeOut; // --ease

  /// `.num { font-variant-numeric: tabular-nums }` for times and counts.
  TextStyle get numeric => TextStyle(
    fontFamily: font,
    fontFamilyFallback: fontFallback,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static const light = WeaveTokens(
    ground: Color(0xFFF5F5F3),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFEEEEEE),
    hover: Color(0xFFF3F3F2),
    border: Color(0xFFE6E6E6),
    rule: Color(0xFFF0F0F0),
    control: Color(0xFFD4D4D4),
    text: Color(0xFF0A0A0A),
    muted: Color(0xFF5F5F5F),
    faint: Color(0xFF6B6B6B),
    primary: Color(0xFF141414),
    onPrimary: Color(0xFFFFFFFF),
    negative: Color(0xFFC4242A),
    positive: Color(0xFF2E7D32),
    pillNeutralBg: Color(0xFFEEEEEE),
    pillNeutralInk: Color(0xFF3D3D3D),
    pillNegativeBg: Color(0xFFFFEDEA),
    pillNegativeInk: Color(0xFF831C1E),
    // 0 12px 32px rgba(0,0,0,.14), 0 0 0 1px rgba(0,0,0,.06)
    floatShadow: [
      BoxShadow(
        color: Color(0x24000000),
        offset: Offset(0, 12),
        blurRadius: 32,
      ),
      BoxShadow(color: Color(0x0F000000), spreadRadius: 1),
    ],
    paperMix: 0.22,
  );

  static const dark = WeaveTokens(
    ground: Color(0xFF0F0F0F),
    surface: Color(0xFF171717),
    raised: Color(0xFF262626),
    hover: Color(0xFF1F1F1F),
    border: Color(0xFF2A2A2A),
    rule: Color(0xFF212121),
    control: Color(0xFF444444),
    text: Color(0xFFF2F2F2),
    muted: Color(0xFFB4B4B4),
    faint: Color(0xFF949494),
    primary: Color(0xFFF2F2F2),
    onPrimary: Color(0xFF0A0A0A),
    negative: Color(0xFFEF6B6B),
    positive: Color(0xFF3FC07A),
    pillNeutralBg: Color(0xFF262626),
    pillNeutralInk: Color(0xFFD4D4D4),
    pillNegativeBg: Color(0xFF2C1A1A),
    pillNegativeInk: Color(0xFFEF8A8A),
    // 0 16px 40px rgba(0,0,0,.6), 0 0 0 1px #2e2e2e
    floatShadow: [
      BoxShadow(
        color: Color(0x99000000),
        offset: Offset(0, 16),
        blurRadius: 40,
      ),
      BoxShadow(color: Color(0xFF2E2E2E), spreadRadius: 1),
    ],
    paperMix: 0.16,
  );

  @override
  WeaveTokens copyWith({
    Color? ground,
    Color? surface,
    Color? raised,
    Color? hover,
    Color? border,
    Color? rule,
    Color? control,
    Color? text,
    Color? muted,
    Color? faint,
    Color? primary,
    Color? onPrimary,
    Color? negative,
    Color? positive,
    Color? pillNeutralBg,
    Color? pillNeutralInk,
    Color? pillNegativeBg,
    Color? pillNegativeInk,
    List<BoxShadow>? floatShadow,
    double? paperMix,
  }) => WeaveTokens(
    ground: ground ?? this.ground,
    surface: surface ?? this.surface,
    raised: raised ?? this.raised,
    hover: hover ?? this.hover,
    border: border ?? this.border,
    rule: rule ?? this.rule,
    control: control ?? this.control,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    faint: faint ?? this.faint,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    negative: negative ?? this.negative,
    positive: positive ?? this.positive,
    pillNeutralBg: pillNeutralBg ?? this.pillNeutralBg,
    pillNeutralInk: pillNeutralInk ?? this.pillNeutralInk,
    pillNegativeBg: pillNegativeBg ?? this.pillNegativeBg,
    pillNegativeInk: pillNegativeInk ?? this.pillNegativeInk,
    floatShadow: floatShadow ?? this.floatShadow,
    paperMix: paperMix ?? this.paperMix,
  );

  @override
  WeaveTokens lerp(ThemeExtension<WeaveTokens>? other, double t) {
    if (other is! WeaveTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return WeaveTokens(
      ground: c(ground, other.ground),
      surface: c(surface, other.surface),
      raised: c(raised, other.raised),
      hover: c(hover, other.hover),
      border: c(border, other.border),
      rule: c(rule, other.rule),
      control: c(control, other.control),
      text: c(text, other.text),
      muted: c(muted, other.muted),
      faint: c(faint, other.faint),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      negative: c(negative, other.negative),
      positive: c(positive, other.positive),
      pillNeutralBg: c(pillNeutralBg, other.pillNeutralBg),
      pillNeutralInk: c(pillNeutralInk, other.pillNeutralInk),
      pillNegativeBg: c(pillNegativeBg, other.pillNegativeBg),
      pillNegativeInk: c(pillNegativeInk, other.pillNegativeInk),
      floatShadow:
          BoxShadow.lerpList(floatShadow, other.floatShadow, t) ?? floatShadow,
      paperMix: paperMix + (other.paperMix - paperMix) * t,
    );
  }
}

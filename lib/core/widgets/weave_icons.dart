import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The one outline icon set of design-02 (`docs/design-02/assets/icons.js`),
/// copied verbatim: 16 px on a 16 grid, 1.5 px stroke, `currentColor`.
/// The Weave mark is [WeaveMark], not an icon.
enum WeaveIcons {
  check(r'<path d="M3.5 8.5 6.5 11.5 12.5 4.5"/>'),
  chevDown(r'<path d="M4.5 6.5 8 10l3.5-3.5"/>'),
  chevRight(r'<path d="M6.5 4.5 10 8l-3.5 3.5"/>', size: 12),
  back(r'<path d="M10 3.5 5.5 8l4.5 4.5"/>'),
  expand(r'<path d="M9.5 2.5h4v4M13.5 2.5 9 7M6.5 13.5h-4v-4M2.5 13.5 7 9"/>'),
  hide(r'<path d="M4.5 5 8 8.5 11.5 5"/><path d="M3 12h10"/>'),
  bell(r'<path d="M4 11V7.5a4 4 0 0 1 8 0V11l1 1.5H3z"/><path d="M6.5 14h3"/>'),
  alert(
    r'<circle cx="8" cy="8" r="6"/><path d="M8 4.8v3.8M8 11.1v.1"/>',
    size: 12,
  ),
  corner(
    r'<rect x="2.5" y="2.5" width="11" height="11" rx="2"/><rect x="8.5" y="4.5" width="3" height="2" rx=".5" fill="currentColor"/>',
  ),
  clock(r'<circle cx="8" cy="8" r="5.5"/><path d="M8 5v3l2 1.5"/>'),
  repeat(
    r'<path d="M3 7V6a2 2 0 0 1 2-2h7.5"/><path d="m10.5 2 2 2-2 2"/><path d="M13 9v1a2 2 0 0 1-2 2H3.5"/><path d="m5.5 14-2-2 2-2"/>',
  ),
  cloud(
    r'<path d="M4.5 12.5a3 3 0 0 1-.3-6A4 4 0 0 1 12 6a3.2 3.2 0 0 1 .3 6.5z"/><path d="m6 9.5 1.5 1.5 2.5-3"/>',
  ),
  cloudOff(
    r'<path d="M6 4.6A4 4 0 0 1 12 6a3.2 3.2 0 0 1 1.9 5.3M11 12.5H4.5a3 3 0 0 1-.5-6"/><path d="M2.5 2.5l11 11"/>',
  ),
  lock(
    r'<rect x="3.5" y="7" width="9" height="6.5" rx="1.5"/><path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2"/>',
  ),
  search(r'<circle cx="7" cy="7" r="4.5"/><path d="m10.5 10.5 3 3"/>'),
  plus(r'<path d="M8 3v10M3 8h10"/>'),
  sun(
    r'<circle cx="8" cy="8" r="3"/><path d="M8 1.5v1.5M8 13v1.5M1.5 8H3M13 8h1.5M3.4 3.4l1 1M11.6 11.6l1 1M3.4 12.6l1-1M11.6 4.4l1-1"/>',
  ),
  list(
    r'<path d="M6 4.5h7.5M6 8h7.5M6 11.5h7.5"/><circle cx="3" cy="4.5" r=".6" fill="currentColor"/><circle cx="3" cy="8" r=".6" fill="currentColor"/><circle cx="3" cy="11.5" r=".6" fill="currentColor"/>',
  ),
  archive(
    r'<rect x="2" y="3" width="12" height="3" rx="1"/><path d="M3 6v6.5a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1V6M6.5 9h3"/>',
  ),
  trash(r'<path d="M2.5 4.5h11M6 4.5V3h4v1.5M4 4.5l.7 9h6.6l.7-9"/>'),
  gear(
    r'<circle cx="8" cy="8" r="2"/><path d="M8 1.8v1.6M8 12.6v1.6M1.8 8h1.6M12.6 8h1.6M3.6 3.6l1.1 1.1M11.3 11.3l1.1 1.1M3.6 12.4l1.1-1.1M11.3 4.7l1.1-1.1"/>',
  ),
  screen(
    r'<rect x="2" y="3" width="12" height="8.5" rx="1.5"/><path d="M5.5 14h5"/><rect x="4.5" y="5.5" width="5" height="2" rx=".6"/>',
  ),
  pin(r'<path d="M6 2.5h4l-.5 4 2 2H4.5l2-2z"/><path d="M8 8.5v5"/>'),
  share(
    r'<path d="M8 10V2.5M5 5.5l3-3 3 3"/><path d="M3.5 8.5v4a1 1 0 0 0 1 1h7a1 1 0 0 0 1-1v-4"/>',
  ),
  more(
    r'<circle cx="3.5" cy="8" r=".9" fill="currentColor"/><circle cx="8" cy="8" r=".9" fill="currentColor"/><circle cx="12.5" cy="8" r=".9" fill="currentColor"/>',
  ),
  menu(r'<path d="M2.5 4.5h11M2.5 8h11M2.5 11.5h11"/>'),
  pause(r'<path d="M6 4v8M10 4v8"/>'),
  show(r'<rect x="2.5" y="5" width="11" height="6" rx="1.5"/>'),
  text(r'<path d="M3.5 4h9M8 4v8.5"/>'),
  close(r'<path d="M4 4l8 8M12 4l-8 8"/>'),
  device(
    r'<rect x="4.5" y="2" width="7" height="12" rx="1.5"/><path d="M7.3 12h1.4"/>',
  ),
  laptop(
    r'<rect x="3" y="3.5" width="10" height="7" rx="1"/><path d="M1.5 12.5h13"/>',
  ),
  key(
    r'<circle cx="5.5" cy="10.5" r="3"/><path d="m7.6 8.4 5.4-5.4M11 5l1.5 1.5"/>',
  ),
  grip(
    r'<circle cx="2" cy="2" r="1.2"/><circle cx="6" cy="2" r="1.2"/><circle cx="2" cy="7" r="1.2"/><circle cx="6" cy="7" r="1.2"/><circle cx="2" cy="12" r="1.2"/><circle cx="6" cy="12" r="1.2"/>',
    w: 8,
    h: 14,
    size: 8,
    attrs: r'fill="currentColor"',
  ),
  tick(
    r'<path d="M2 5.2 4.1 7.3 8 2.9"/>',
    w: 10,
    h: 10,
    size: 10,
    attrs:
        r'fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"',
  ),
  resize(
    r'<path d="M10.5 4.5 4.5 10.5M10.5 8l-2.5 2.5"/>',
    w: 12,
    h: 12,
    size: 12,
    attrs:
        r'fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"',
  );

  const WeaveIcons(
    this.body, {
    this.w = 16,
    this.h = 16,
    this.size = 16,
    this.attrs,
  });

  /// SVG children, as in icons.js.
  final String body;

  /// The viewBox width and height.
  final double w;
  final double h;

  /// The width icons.js draws it at.
  final double size;

  /// Root attributes of an icon that is not on the shared stroke template
  /// (grip, tick, resize); null for the template.
  final String? attrs;

  String svg(double strokeWidth) {
    final root =
        attrs ??
        'fill="none" stroke="currentColor" stroke-width="$strokeWidth" '
            'stroke-linecap="round" stroke-linejoin="round"';
    // currentColor → black, recoloured by [WeaveIcon]'s colour filter.
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${_n(w)} ${_n(h)}" '
            '$root>$body</svg>'
        .replaceAll('currentColor', '#000');
  }

  static String _n(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
}

/// Draws a [WeaveIcons] icon in [color] (default: the ambient icon colour,
/// as CSS `currentColor`). [size] is the width; the height follows the
/// viewBox. [strokeWidth] is in viewBox units (icons.js 1.5; the iOS current
/// tab uses 2).
class WeaveIcon extends StatelessWidget {
  const WeaveIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.strokeWidth = 1.5,
  });

  final WeaveIcons icon;
  final double? size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final w = size ?? icon.size;
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFF000000);
    return SvgPicture.string(
      icon.svg(strokeWidth),
      width: w,
      height: w * icon.h / icon.w,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

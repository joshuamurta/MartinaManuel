import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta y tipografías del sitio web (web/css/styles.css).
abstract final class MM {
  static const cream = Color(0xFFFBF6EF);
  static const paper = Color(0xFFFFFDF9);
  static const ink = Color(0xFF16324A); // azul noche: textos y botones principales
  static const inkSoft = Color(0xFF3B5266);
  static const rio = Color(0xFFA9DCD8); // turquesa del Atuel
  static const rioDeep = Color(0xFF1E6D73);
  static const alamo = Color(0xFFCFE0BF); // verde álamo
  static const sauce = Color(0xFFB7D6C4); // verde sauce
  static const forest = Color(0xFF234B33);
  static const ocre = Color(0xFFF2C86B); // sol / etiquetas
  static const sand = Color(0xFFF3D4BF);
  static const canyon = Color(0xFFB9512F); // terracota del cañón
  static const soft = Color(0xFFCFE3F0);

  static TextStyle display(double size, {Color color = ink}) =>
      GoogleFonts.bricolageGrotesque(fontSize: size, fontWeight: FontWeight.w800, height: 1, letterSpacing: -size * .02, color: color);

  static TextStyle script(double size, {Color color = ink}) =>
      GoogleFonts.fraunces(fontSize: size, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, color: color);

  static TextStyle label({Color color = forest}) =>
      GoogleFonts.figtree(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .8, color: color);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: rioDeep,
        primary: ink,
        onPrimary: cream,
        secondary: rioDeep,
        tertiary: ocre,
        error: canyon,
        surface: paper,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: cream,
    );
    final text = GoogleFonts.figtreeTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink);
    final r = BorderRadius.circular(14);
    return base.copyWith(
      textTheme: text.copyWith(
        headlineLarge: display(34),
        headlineMedium: display(28),
        headlineSmall: display(22),
        titleLarge: display(20),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: display(22),
      ),
      cardTheme: CardThemeData(
        color: paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ink.withValues(alpha: .08))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: cream,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          shape: const StadiumBorder(),
          side: BorderSide(color: ink.withValues(alpha: .2), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: forest, textStyle: GoogleFonts.figtree(fontWeight: FontWeight.w700)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: GoogleFonts.figtree(fontWeight: FontWeight.w600, color: forest),
        border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: forest.withValues(alpha: .18), width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: forest.withValues(alpha: .18), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: rioDeep, width: 2)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: paper,
        selectedColor: sauce,
        side: BorderSide(color: ink.withValues(alpha: .12), width: 1.5),
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.figtree(fontWeight: FontWeight.w700, fontSize: 13, color: ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paper,
        indicatorColor: sauce,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(GoogleFonts.figtree(fontWeight: FontWeight.w700, fontSize: 12)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: soft,
        indicatorColor: paper,
        selectedLabelTextStyle: GoogleFonts.figtree(fontWeight: FontWeight.w800, color: ink),
        unselectedLabelTextStyle: GoogleFonts.figtree(fontWeight: FontWeight.w600, color: inkSoft),
      ),
      dividerTheme: DividerThemeData(color: ink.withValues(alpha: .08)),
      snackBarTheme: const SnackBarThemeData(backgroundColor: ink, behavior: SnackBarBehavior.floating),
    );
  }
}

/// Etiqueta inclinada tipo "sticker" del sitio.
class Sticker extends StatelessWidget {
  const Sticker(this.text, {super.key, this.color = MM.ocre});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -.05,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          child: Text(text, style: MM.script(14)),
        ),
      );
}

/// Logo del sitio: sol, montañas y río dentro de un círculo.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _BrandPainter());
}

class _BrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48);
    canvas.drawCircle(const Offset(24, 24), 23, Paint()..color = MM.ink);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(6, 31)
        ..lineTo(15, 21)
        ..lineTo(21, 27)
        ..lineTo(28, 16)
        ..lineTo(42, 31),
      stroke..color = MM.cream,
    );
    canvas.drawPath(
      Path()
        ..moveTo(8, 37)
        ..cubicTo(13, 34, 17, 39, 24, 36)
        ..cubicTo(31, 33, 35, 37, 40, 35),
      stroke..color = MM.rio,
    );
    canvas.drawCircle(const Offset(33, 14), 3.4, Paint()..color = MM.ocre);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Encabezado de sección: sticker + título grande, como en la web.
class SectionHead extends StatelessWidget {
  const SectionHead({super.key, required this.sticker, required this.title, this.trailing});
  final String sticker;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Sticker(sticker),
                  const SizedBox(height: 12),
                  Text(title, style: MM.display(MediaQuery.sizeOf(context).width < 600 ? 30 : 40)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

/// Chip de dato chico (capacidad, m², etc.).
class InfoChip extends StatelessWidget {
  const InfoChip(this.text, {super.key, this.icon, this.color = MM.paper, this.fg = MM.ink});
  final String text;
  final IconData? icon;
  final Color color;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: MM.ink.withValues(alpha: .12), width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg)),
        ]),
      );
}

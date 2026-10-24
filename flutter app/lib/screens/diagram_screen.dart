import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// La hoja DIAGRAMA: una fila por cabaña y una columna por noche del mes.
/// Tocar una noche libre y después la última noche crea una reserva.
class DiagramScreen extends StatefulWidget {
  const DiagramScreen({super.key});

  @override
  State<DiagramScreen> createState() => _DiagramScreenState();
}

class _DiagramScreenState extends State<DiagramScreen> {
  DateTime _month = DateTime(today().year, today().month);
  ({int cabin, DateTime day})? _start; // primera noche elegida
  final _hScroll = ScrollController();

  static const _labelW = 104.0;
  static const _rowH = 58.0;
  static const _headH = 46.0;

  void _shift(int months) => setState(() {
        _month = DateTime(_month.year, _month.month + months);
        _start = null;
      });

  void _tapNight(int cabin, DateTime day) {
    final s = _start;
    if (s == null || s.cabin != cabin || day.isBefore(s.day)) {
      setState(() => _start = (cabin: cabin, day: day));
      return;
    }
    setState(() => _start = null);
    context.push('/reservas/nueva?cabin=$cabin&in=${ymd(s.day)}&out=${ymd(day.add(const Duration(days: 1)))}');
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = DateTime(_month.year, _month.month);
    final to = DateTime(_month.year, _month.month + 1);
    final days = nightsBetween(from, to);
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < 600;

    return SettingsBuilder(
      builder: (context, settings) => StreamView<List<Reservation>>(
        stream: Repo.instance.reservationsBetween(ymd(from), ymd(to)),
        builder: (context, all) {
          final list = all.where((r) => r.occupies).toList();
          return LayoutBuilder(builder: (context, box) {
            final gutter = phone ? 12.0 : 32.0;
            final avail = box.maxWidth - 2 * gutter - _labelW;
            final cellW = (avail / days).clamp(phone ? 40.0 : 34.0, 64.0);
            _scrollToToday(from, cellW, avail);

            return PageBody(
              maxWidth: 1600,
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 96),
              children: [
                SectionHead(
                  sticker: 'Diagrama',
                  title: fmtMonth(_month),
                  trailing: _MonthNav(onPrev: () => _shift(-1), onNext: () => _shift(1), onToday: () => setState(() {
                        _month = DateTime(today().year, today().month);
                        _start = null;
                      })),
                ),
                _Occupancy(list: list, from: from, days: days, settings: settings),
                const SizedBox(height: 14),
                if (_start != null)
                  _Banner(
                    text: 'Cabaña ${_start!.cabin}: llegada ${fmtDay(_start!.day)}. Ahora tocá la última noche.',
                    onCancel: () => setState(() => _start = null),
                  )
                else
                  Text(
                    phone ? 'Tocá una noche libre para empezar una reserva.' : 'Tocá la primera noche libre y después la última para cargar una reserva.',
                    style: const TextStyle(color: MM.inkSoft, fontSize: 13.5),
                  ),
                const SizedBox(height: 10),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: _labelW,
                      child: Column(children: [
                        SizedBox(height: _headH, child: Center(child: Text('Cabaña', style: MM.label()))),
                        for (final c in settings.cabins) _CabinLabel(cabin: c, height: _rowH),
                      ]),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _hScroll,
                        child: SingleChildScrollView(
                          controller: _hScroll,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: cellW * days,
                            child: Column(children: [
                              _DayHeader(from: from, days: days, cellW: cellW, height: _headH, holidays: settings.holidays),
                              for (final c in settings.cabins)
                                _CabinRow(
                                  cabin: c.id,
                                  from: from,
                                  days: days,
                                  cellW: cellW,
                                  height: _rowH,
                                  holidays: settings.holidays,
                                  reservations: list.where((r) => r.cabins.contains(c.id)).toList(),
                                  selected: _start?.cabin == c.id ? _start!.day : null,
                                  onTapNight: (d) => _tapNight(c.id, d),
                                ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                const ColorLegend(),
                ..._holidayList(settings, from, to),
              ],
            );
          });
        },
      ),
    );
  }

  DateTime? _scrolledFor;
  void _scrollToToday(DateTime from, double cellW, double avail) {
    if (_scrolledFor == from) return;
    _scrolledFor = from;
    final t = today();
    if (t.year != from.year || t.month != from.month) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_hScroll.hasClients) _hScroll.jumpTo(0);
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hScroll.hasClients) return;
      final x = ((t.day - 2) * cellW).clamp(0.0, _hScroll.position.maxScrollExtent);
      _hScroll.jumpTo(x);
    });
  }

  List<Widget> _holidayList(Settings s, DateTime from, DateTime to) {
    final items = s.holidays.entries.where((e) => e.key.compareTo(ymd(from)) >= 0 && e.key.compareTo(ymd(to)) < 0).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in items) InfoChip('${parseYmd(e.key).day} · ${e.value}', icon: Icons.flag_outlined, color: MM.ocre.withValues(alpha: .25)),
      ]),
    ];
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav({required this.onPrev, required this.onNext, required this.onToday});
  final VoidCallback onPrev, onNext, onToday;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton.filledTonal(tooltip: 'Mes anterior', onPressed: onPrev, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 4),
        TextButton(onPressed: onToday, child: const Text('Hoy')),
        const SizedBox(width: 4),
        IconButton.filledTonal(tooltip: 'Mes siguiente', onPressed: onNext, icon: const Icon(Icons.arrow_forward)),
      ]);
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.onCancel});
  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        decoration: BoxDecoration(color: MM.ocre, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
          TextButton(onPressed: onCancel, child: const Text('Cancelar')),
        ]),
      );
}

class _CabinLabel extends StatelessWidget {
  const _CabinLabel({required this.cabin, required this.height});
  final Cabin cabin;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: MM.ink.withValues(alpha: .08)))),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: MM.cream, shape: BoxShape.circle),
            child: Text('${cabin.id}', style: MM.display(16)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('máx ${cabin.maxPeople}', style: const TextStyle(fontSize: 12, color: MM.inkSoft, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.from, required this.days, required this.cellW, required this.height, required this.holidays});
  final DateTime from;
  final int days;
  final double cellW, height;
  final Map<String, String> holidays;

  @override
  Widget build(BuildContext context) {
    final t = today();
    final dow = DateFormat('EEEEE', 'es_AR');
    return Row(children: [
      for (var i = 0; i < days; i++)
        Builder(builder: (context) {
          final d = from.add(Duration(days: i));
          final isToday = d == t;
          final weekend = d.weekday >= DateTime.saturday;
          final holiday = holidays[ymd(d)];
          return Tooltip(
            message: holiday ?? '',
            child: Container(
              width: cellW,
              height: height,
              decoration: BoxDecoration(
                color: holiday != null ? MM.ocre.withValues(alpha: .35) : (weekend ? MM.cream : null),
                border: Border(left: BorderSide(color: MM.ink.withValues(alpha: .06))),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(dow.format(d).toUpperCase(), style: MM.label(color: MM.inkSoft).copyWith(fontSize: 10)),
                const SizedBox(height: 2),
                Container(
                  width: 24,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: isToday ? BoxDecoration(color: MM.ink, borderRadius: BorderRadius.circular(8)) : null,
                  child: Text('${d.day}', style: MM.display(14, color: isToday ? MM.cream : MM.ink)),
                ),
              ]),
            ),
          );
        }),
    ]);
  }
}

class _CabinRow extends StatelessWidget {
  const _CabinRow({
    required this.cabin,
    required this.from,
    required this.days,
    required this.cellW,
    required this.height,
    required this.holidays,
    required this.reservations,
    required this.selected,
    required this.onTapNight,
  });
  final int cabin;
  final DateTime from;
  final int days;
  final double cellW, height;
  final Map<String, String> holidays;
  final List<Reservation> reservations;
  final DateTime? selected;
  final ValueChanged<DateTime> onTapNight;

  @override
  Widget build(BuildContext context) {
    final t = today();
    final bars = <Widget>[];
    for (final r in reservations) {
      final start = nightsBetween(from, r.inDate).clamp(0, days);
      final end = nightsBetween(from, r.outDate).clamp(0, days);
      if (end <= start) continue;
      bars.add(Positioned(
        left: start * cellW + (r.inDate.isBefore(from) ? 0 : 3),
        width: (end - start) * cellW - (r.inDate.isBefore(from) ? 0 : 3) - (nightsBetween(from, r.outDate) > days ? 0 : 3),
        top: 7,
        bottom: 7,
        child: _Bar(r: r, continuesLeft: r.inDate.isBefore(from), continuesRight: nightsBetween(from, r.outDate) > days),
      ));
    }

    return Container(
      height: height,
      decoration: BoxDecoration(border: Border(top: BorderSide(color: MM.ink.withValues(alpha: .08)))),
      child: Stack(children: [
        Row(children: [
          for (var i = 0; i < days; i++)
            Builder(builder: (context) {
              final d = from.add(Duration(days: i));
              final isSel = selected == d;
              return InkWell(
                onTap: () => onTapNight(d),
                child: Container(
                  width: cellW,
                  height: height,
                  decoration: BoxDecoration(
                    color: isSel
                        ? MM.ocre
                        : holidays.containsKey(ymd(d))
                            ? MM.ocre.withValues(alpha: .14)
                            : d == t
                                ? MM.soft.withValues(alpha: .5)
                                : null,
                    border: Border(left: BorderSide(color: MM.ink.withValues(alpha: .06))),
                  ),
                  child: isSel ? const Icon(Icons.login, size: 18) : null,
                ),
              );
            }),
        ]),
        ...bars,
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.r, required this.continuesLeft, required this.continuesRight});
  final Reservation r;
  final bool continuesLeft, continuesRight;

  @override
  Widget build(BuildContext context) {
    final c = reservationColors(r);
    const rad = Radius.circular(10);
    final label = r.isBlock ? (r.name.isEmpty ? 'Bloqueado' : r.name) : r.name;
    return Tooltip(
      message: '${r.name}\n${fmtDay(r.inDate)} → ${fmtDay(r.outDate)}${r.people != null ? '\n${r.people} personas' : ''}\n${reservationStateText(r)}',
      child: Material(
        color: c.bg,
        borderRadius: BorderRadius.horizontal(left: continuesLeft ? Radius.zero : rad, right: continuesRight ? Radius.zero : rad),
        child: InkWell(
          onTap: () => context.push('/reservas/${r.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              if (r.warnings.isNotEmpty) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.error_outline, size: 14, color: MM.canyon)),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: label, style: TextStyle(fontWeight: FontWeight.w800, color: c.fg)),
                    if (r.people != null) TextSpan(text: '  ${r.people}p', style: TextStyle(color: c.fg.withValues(alpha: .8))),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              if (r.breakfast) Icon(Icons.free_breakfast_outlined, size: 14, color: c.fg),
              if (r.pets) Icon(Icons.pets, size: 14, color: c.fg),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Ocupación del mes, total y por cabaña (la columna de % de la planilla).
class _Occupancy extends StatelessWidget {
  const _Occupancy({required this.list, required this.from, required this.days, required this.settings});
  final List<Reservation> list;
  final DateTime from;
  final int days;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final to = from.add(Duration(days: days));
    // Noches distintas: si dos reservas se pisan, la noche cuenta una vez.
    int nightsFor(int cabin) {
      final nights = <int>{};
      for (final r in list.where((r) => !r.isBlock && r.cabins.contains(cabin))) {
        final a = nightsBetween(from, r.inDate).clamp(0, days);
        final b = nightsBetween(from, r.outDate).clamp(0, days);
        for (var i = a; i < b; i++) {
          nights.add(i);
        }
      }
      return nights.length;
    }

    final per = {for (final c in settings.cabins) c.id: nightsFor(c.id)};
    final total = per.values.fold(0, (a, b) => a + b);
    final pct = total / (days * settings.cabins.length) * 100;
    final guests = list.where((r) => !r.isBlock && !r.inDate.isBefore(from) && r.inDate.isBefore(to)).length;

    return Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      InfoChip('Ocupación ${pct.toStringAsFixed(0)}%', icon: Icons.donut_large, color: MM.sauce, fg: MM.forest),
      InfoChip('$total noches vendidas', icon: Icons.nights_stay_outlined),
      InfoChip('$guests llegadas', icon: Icons.login),
      for (final e in per.entries) InfoChip('C${e.key} ${(e.value / days * 100).toStringAsFixed(0)}%'),
    ]);
  }
}

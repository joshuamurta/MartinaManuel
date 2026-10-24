import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Ocupación, facturación y canales por año.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _year = today().year;
  late Future<List<Reservation>> _all = Repo.instance.all();

  static const _months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Reservation>>(
        future: _all,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('No se pudo cargar: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final res = snap.data!.where((r) => r.occupies && !r.isBlock).toList();
          final years = {for (final r in res) r.inDate.year}.toList()..sort();

          // Noches ocupadas por mes (cada cabaña cuenta) y facturación por mes de llegada.
          final nights = List<int>.filled(12, 0);
          final revenue = List<num>.filled(12, 0);
          final arrivals = List<int>.filled(12, 0);
          final perCabin = <int, int>{};
          final perChannel = <String, int>{};
          // Cada noche de cada cabaña cuenta una vez aunque haya reservas superpuestas.
          final seen = <String>{};
          for (final r in res) {
            for (var d = r.inDate; d.isBefore(r.outDate); d = d.add(const Duration(days: 1))) {
              if (d.year != _year) continue;
              for (final c in r.cabins) {
                if (!seen.add('$c ${ymd(d)}')) continue;
                nights[d.month - 1]++;
                perCabin[c] = (perCabin[c] ?? 0) + 1;
              }
            }
            if (r.inDate.year == _year) {
              revenue[r.inDate.month - 1] += r.total ?? 0;
              arrivals[r.inDate.month - 1]++;
              final ch = channels[r.channel] ?? 'Sin dato';
              perChannel[ch] = (perChannel[ch] ?? 0) + 1;
            }
          }
          final capacity = [for (var m = 1; m <= 12; m++) nightsBetween(DateTime(_year, m), DateTime(_year, m + 1)) * defaultCabins.length];
          final occ = [for (var i = 0; i < 12; i++) nights[i] / capacity[i]];
          final daysInYear = nightsBetween(DateTime(_year), DateTime(_year + 1));
          final totalRevenue = revenue.fold<num>(0, (a, b) => a + b);
          final totalNights = nights.fold(0, (a, b) => a + b);
          final channelList = perChannel.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

          return PageBody(children: [
            SectionHead(
              sticker: 'Números',
              title: 'Temporada $_year',
              trailing: DropdownButton<int>(
                value: _year,
                items: [for (final y in {...years, today().year}.toList()..sort()) DropdownMenuItem(value: y, child: Text('$y'))],
                onChanged: (y) => setState(() => _year = y ?? _year),
              ),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              InfoChip('Facturado ${fmtMoney(totalRevenue)}', icon: Icons.payments_outlined, color: MM.sauce, fg: MM.forest),
              InfoChip('$totalNights noches vendidas', icon: Icons.nights_stay_outlined),
              InfoChip('Ocupación anual ${(totalNights / (daysInYear * defaultCabins.length) * 100).toStringAsFixed(0)}%', icon: Icons.donut_large),
              InfoChip('${arrivals.fold(0, (a, b) => a + b)} reservas', icon: Icons.event_note_outlined),
            ]),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _all = Repo.instance.all()),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
            _ChartCard(
              title: 'Ocupación por mes',
              labels: _months,
              values: occ,
              format: (v) => '${(v * 100).round()}%',
              color: MM.rioDeep,
              max: 1,
            ),
            const SizedBox(height: 16),
            _ChartCard(
              title: 'Facturación por mes de llegada',
              labels: _months,
              values: [for (final v in revenue) v.toDouble()],
              format: (v) => v >= 1e6 ? '${(v / 1e6).toStringAsFixed(1)}M' : '${(v / 1e3).round()}k',
              color: MM.forest,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth > 700;
              final a = _BarsCard(
                title: 'Noches por cabaña',
                rows: [for (final c in defaultCabins) MapEntry('Cabaña ${c.id}', perCabin[c.id] ?? 0)],
                suffix: (v) => '$v · ${(v / daysInYear * 100).round()}%',
              );
              final b = _BarsCard(title: 'De dónde vienen las reservas', rows: channelList, suffix: (v) => '$v');
              return wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)])
                  : Column(children: [a, const SizedBox(height: 16), b]);
            }),
          ]);
        },
      );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.labels, required this.values, required this.format, required this.color, this.max});
  final String title;
  final List<String> labels;
  final List<double> values;
  final String Function(double) format;
  final Color color;
  final double? max;

  @override
  Widget build(BuildContext context) {
    final top = max ?? values.fold<double>(0, (a, b) => b > a ? b : a);
    final current = today().month - 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: MM.display(20)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Tooltip(
                    message: '${labels[i]}: ${format(values[i])}',
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      FittedBox(child: Text(values[i] == 0 ? '' : format(values[i]), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                      const SizedBox(height: 4),
                      Container(
                        height: top == 0 ? 0 : 130 * (values[i] / top).clamp(0, 1),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == current ? MM.ocre : color.withValues(alpha: .8),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(labels[i], style: const TextStyle(fontSize: 11, color: MM.inkSoft)),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BarsCard extends StatelessWidget {
  const _BarsCard({required this.title, required this.rows, required this.suffix});
  final String title;
  final List<MapEntry<String, int>> rows;
  final String Function(int) suffix;

  @override
  Widget build(BuildContext context) {
    final top = rows.fold<int>(1, (a, e) => e.value > a ? e.value : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: MM.display(20)),
          const SizedBox(height: 12),
          if (rows.isEmpty) const Text('Sin datos.'),
          for (final e in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 120, child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: e.value / top, minHeight: 10, backgroundColor: MM.cream, color: MM.rioDeep),
                  ),
                ),
                SizedBox(width: 90, child: Text(suffix(e.value), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
        ]),
      ),
    );
  }
}

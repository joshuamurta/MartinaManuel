import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repo.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum _Filter { proximas, revisar, historial }

/// Lista y búsqueda de reservas (las hojas "desarrollo" de la planilla).
class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  _Filter _filter = _Filter.proximas;
  String _q = '';
  Future<List<Reservation>>? _history;

  bool _matches(Reservation r) {
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return r.name.toLowerCase().contains(q) ||
        (r.contact ?? '').toLowerCase().contains(q) ||
        (r.email ?? '').toLowerCase().contains(q) ||
        (r.invoiceNo ?? '').contains(q) ||
        (r.notes ?? '').toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final history = _filter == _Filter.historial;
    if (history) _history ??= Repo.instance.all();

    Widget list(List<Reservation> all) {
      var items = all.where(_matches).toList();
      if (_filter == _Filter.revisar) items = items.where((r) => r.warnings.isNotEmpty).toList();
      return _ResList(items: items, history: history);
    }

    return Scaffold(
      floatingActionButton: !SessionScope.of(context).perms.canEdit('reservas')
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/reservas/nueva'),
              backgroundColor: MM.ink,
              foregroundColor: MM.cream,
              icon: const Icon(Icons.add),
              label: const Text('Nueva'),
            ),
      body: PageBody(children: [
        const SectionHead(sticker: 'Reservas', title: 'Huéspedes'),
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar por nombre, teléfono, factura o nota'),
          onChanged: (v) => setState(() => _q = v.trim()),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_Filter>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _Filter.proximas, label: Text('Próximas')),
            ButtonSegment(value: _Filter.revisar, label: Text('A revisar')),
            ButtonSegment(value: _Filter.historial, label: Text('Todas')),
          ],
          selected: {_filter},
          onSelectionChanged: (s) => setState(() => _filter = s.first),
        ),
        const SizedBox(height: 12),
        if (history)
          FutureBuilder<List<Reservation>>(
            future: _history,
            builder: (context, snap) {
              if (snap.hasError) return Text('No se pudo cargar: ${snap.error}');
              if (!snap.hasData) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
              return list(snap.data!);
            },
          )
        else
          StreamBuilder<List<Reservation>>(
            stream: Repo.instance.upcoming(),
            builder: (context, snap) {
              if (snap.hasError) return Text('No se pudo cargar: ${snap.error}');
              if (!snap.hasData) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
              return list(snap.data!.where((r) => r.status != ResStatus.cancelada || _filter == _Filter.revisar).toList());
            },
          ),
      ]),
    );
  }
}

class _ResList extends StatelessWidget {
  const _ResList({required this.items, required this.history});
  final List<Reservation> items;
  final bool history;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No hay reservas para mostrar.')));
    }
    // Agrupadas por mes de llegada, como los bloques de la planilla.
    final groups = <String, List<Reservation>>{};
    for (final r in items.take(history ? 400 : items.length)) {
      groups.putIfAbsent(r.checkIn.substring(0, 7), () => []).add(r);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final g in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(fmtMonth(parseYmd('${g.key}-01')).toUpperCase(), style: MM.label()),
        ),
        Card(
          child: Column(children: [
            for (final (i, r) in g.value.indexed) ...[
              if (i > 0) const Divider(height: 1),
              _ResTile(r: r),
            ],
          ]),
        ),
      ],
      if (history && items.length > 400)
        const Padding(padding: EdgeInsets.all(16), child: Text('Se muestran las 400 más recientes. Usá el buscador para encontrar otras.')),
    ]);
  }
}

class _ResTile extends StatelessWidget {
  const _ResTile({required this.r});
  final Reservation r;

  @override
  Widget build(BuildContext context) {
    final c = reservationColors(r);
    return ListTile(
      onTap: () => context.push('/reservas/${r.id}'),
      leading: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${r.inDate.day}', style: MM.display(18, color: c.fg)),
          Text('${r.nights}n', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.fg)),
        ]),
      ),
      title: Row(children: [
        Flexible(child: Text(r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
        if (r.warnings.isNotEmpty) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.error_outline, size: 16, color: MM.canyon)),
      ]),
      subtitle: Text([
        r.cabinsLabel,
        '${fmtShort(r.inDate)} → ${fmtShort(r.outDate)}',
        if (r.people != null) '${r.people}p',
        if (r.channel != null) channels[r.channel] ?? r.channel!,
      ].join(' · ')),
      trailing: Text(reservationStateText(r), style: TextStyle(fontWeight: FontWeight.w700, color: (r.balance ?? 0) > 0 ? MM.canyon : MM.forest)),
    );
  }
}

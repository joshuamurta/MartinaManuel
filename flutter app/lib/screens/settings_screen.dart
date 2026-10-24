import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repo.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => SettingsBuilder(
        builder: (context, s) => PageBody(maxWidth: 900, children: [
          const SectionHead(sticker: 'Ajustes', title: 'El complejo'),
          _CabinsCard(settings: s),
          const SizedBox(height: 16),
          _GeneralCard(settings: s),
          const SizedBox(height: 16),
          _HolidaysCard(settings: s),
          const SizedBox(height: 16),
          const _WebCard(),
          const SizedBox(height: 16),
          const _ImportCard(),
        ]),
      );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title, [this.subtitle]);
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: MM.display(22)),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!, style: const TextStyle(color: MM.inkSoft))),
        ]),
      );
}

class _CabinsCard extends StatefulWidget {
  const _CabinsCard({required this.settings});
  final Settings settings;

  @override
  State<_CabinsCard> createState() => _CabinsCardState();
}

class _CabinsCardState extends State<_CabinsCard> {
  late final _prices = {for (final c in widget.settings.cabins) c.id: TextEditingController(text: c.price?.round().toString() ?? '')};

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _CardTitle('Tarifas por noche', 'Se usan para calcular el total al cargar una reserva.'),
            for (final c in widget.settings.cabins)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/img/cabana-${c.id}.webp', width: 56, height: 44, fit: BoxFit.cover)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('${c.capacity} · ${c.size} m²', style: const TextStyle(fontSize: 12.5, color: MM.inkSoft)),
                    ]),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _prices[c.id],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(prefixText: r'$ ', isDense: true),
                    ),
                  ),
                ]),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () async {
                  final s = widget.settings;
                  await Repo.instance.saveSettings(Settings(
                    cabins: [for (final c in s.cabins) c.copyWith(price: num.tryParse(_prices[c.id]!.text))],
                    holidays: s.holidays,
                    paymentInfo: s.paymentInfo,
                    checkInTime: s.checkInTime,
                    checkOutTime: s.checkOutTime,
                    breakfastPrice: s.breakfastPrice,
                  ));
                  if (context.mounted) toast(context, 'Tarifas guardadas.');
                },
                child: const Text('Guardar tarifas'),
              ),
            ),
          ]),
        ),
      );
}

class _GeneralCard extends StatefulWidget {
  const _GeneralCard({required this.settings});
  final Settings settings;

  @override
  State<_GeneralCard> createState() => _GeneralCardState();
}

class _GeneralCardState extends State<_GeneralCard> {
  late final _pay = TextEditingController(text: widget.settings.paymentInfo ?? '');
  late final _in = TextEditingController(text: widget.settings.checkInTime);
  late final _out = TextEditingController(text: widget.settings.checkOutTime);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _CardTitle('Mensajes de WhatsApp', 'Datos que se completan solos en los mensajes a los huéspedes.'),
            Row(children: [
              Expanded(child: TextField(controller: _in, decoration: const InputDecoration(labelText: 'Check-in desde'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _out, decoration: const InputDecoration(labelText: 'Check-out hasta'))),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _pay,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(labelText: 'Datos para la seña', hintText: 'Alias: martina.manuel.mp\nCBU: …\nTitular: …'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () async {
                  final s = widget.settings;
                  await Repo.instance.saveSettings(Settings(
                    cabins: s.cabins,
                    holidays: s.holidays,
                    paymentInfo: _pay.text.trim(),
                    checkInTime: _in.text.trim(),
                    checkOutTime: _out.text.trim(),
                    breakfastPrice: s.breakfastPrice,
                  ));
                  if (context.mounted) toast(context, 'Guardado.');
                },
                child: const Text('Guardar'),
              ),
            ),
          ]),
        ),
      );
}

class _HolidaysCard extends StatelessWidget {
  const _HolidaysCard({required this.settings});
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final from = ymd(DateTime(today().year, today().month));
    final list = settings.holidays.entries.where((e) => e.key.compareTo(from) >= 0).toList()..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _CardTitle('Feriados y fechas especiales', 'Se resaltan en el diagrama. Agregá los puentes y traslados de cada año.'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in list)
              InputChip(
                label: Text('${fmtShort(parseYmd(e.key))}/${e.key.substring(2, 4)} · ${e.value}'),
                onDeleted: baseHolidays.containsKey(e.key)
                    ? null
                    : () => Repo.instance.saveSettings(_with(settings, {...settings.holidays}..remove(e.key))),
              ),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Agregar fecha'),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: today(), firstDate: DateTime(2024), lastDate: DateTime(2035));
                if (d == null || !context.mounted) return;
                final c = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (dlg) => AlertDialog(
                    title: Text(fmtDay(d)),
                    content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Feriado puente, Vendimia…')),
                    actions: [FilledButton(onPressed: () => Navigator.pop(dlg, c.text.trim()), child: const Text('Agregar'))],
                  ),
                );
                if (name == null || name.isEmpty) return;
                await Repo.instance.saveSettings(_with(settings, {...settings.holidays, ymd(d): name}));
              },
            ),
          ),
        ]),
      ),
    );
  }

  Settings _with(Settings s, Map<String, String> holidays) => Settings(
        cabins: s.cabins,
        holidays: holidays,
        paymentInfo: s.paymentInfo,
        checkInTime: s.checkInTime,
        checkOutTime: s.checkOutTime,
        breakfastPrice: s.breakfastPrice,
      );
}

class _WebCard extends StatefulWidget {
  const _WebCard();

  @override
  State<_WebCard> createState() => _WebCardState();
}

class _WebCardState extends State<_WebCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _CardTitle(
              'Calendario de la web',
              'Cada vez que se guarda una reserva, la web se actualiza sola con las noches ocupadas (sin nombres). Si algo no coincide, publicalo de nuevo.',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.public),
                label: Text(_busy ? 'Publicando…' : 'Publicar disponibilidad ahora'),
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await Repo.instance.publishAvailability();
                          if (context.mounted) toast(context, 'Disponibilidad publicada.');
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),
            ),
          ]),
        ),
      );
}

/// Carga el JSON generado por tools/importar_excel.py a partir de la planilla.
class _ImportCard extends StatefulWidget {
  const _ImportCard();

  @override
  State<_ImportCard> createState() => _ImportCardState();
}

class _ImportCardState extends State<_ImportCard> {
  List<Reservation>? _items;
  Map<String, dynamic>? _stats;
  bool _overwrite = false;
  int? _done;
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    setState(() => _error = null);
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['json'], withData: true);
    final bytes = res?.files.single.bytes;
    if (bytes == null) return;
    try {
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final list = [for (final m in data['reservations'] as List) Reservation.fromImport(Map<String, dynamic>.from(m))];
      setState(() {
        _items = list;
        _stats = Map<String, dynamic>.from(data['stats'] ?? {});
        _done = null;
      });
    } catch (e) {
      setState(() => _error = 'Ese archivo no es el que genera tools/importar_excel.py ($e).');
    }
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _done = 0;
    });
    try {
      final n = await Repo.instance.importReservations(_items!, overwrite: _overwrite, onProgress: (d) => setState(() => _done = d));
      if (mounted) toast(context, 'Listo: $n reservas importadas.');
    } catch (e) {
      setState(() => _error = 'Falló la importación: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final upcoming = items?.where((r) => r.checkOut.compareTo(ymd(today())) > 0).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _CardTitle(
            'Importar la planilla',
            'Primero se convierte el Excel con tools/importar_excel.py (ver README). Después elegí acá el archivo importacion.json.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(onPressed: _busy ? null : _pick, icon: const Icon(Icons.upload_file), label: const Text('Elegir importacion.json')),
          ),
          if (items != null) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              InfoChip('${items.length} reservas', icon: Icons.event_note_outlined),
              InfoChip('$upcoming de hoy en adelante', icon: Icons.upcoming_outlined),
              if (_stats?['matchedWithDiagram'] != null) InfoChip('${_stats!['matchedWithDiagram']} cruzadas con el diagrama'),
              if (_stats?['withWarnings'] != null) InfoChip('${_stats!['withWarnings']} para revisar', icon: Icons.error_outline, color: MM.sand),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _overwrite,
              onChanged: _busy ? null : (v) => setState(() => _overwrite = v),
              title: const Text('Pisar las que ya estaban importadas'),
              subtitle: const Text('Apagado: sólo agrega las nuevas y no toca lo que ya se corrigió en la app.'),
            ),
            if (_done != null) LinearProgressIndicator(value: _done! / items.length),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _busy ? null : _import, child: Text(_busy ? 'Importando ${_done ?? 0}…' : 'Importar')),
            ),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: MM.canyon))),
        ]),
      ),
    );
  }
}

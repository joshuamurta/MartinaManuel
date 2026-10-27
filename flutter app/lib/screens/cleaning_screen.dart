import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Lo que tienen que preparar las mucamas: salidas, llegadas con el armado de
/// camas, e indicaciones sueltas. No muestra nombres ni datos de huéspedes.
class CleaningScreen extends StatelessWidget {
  const CleaningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final canEdit = SessionScope.of(context).perms.canEdit('limpieza');
    return Scaffold(
      floatingActionButton: !canEdit
          ? null
          : FloatingActionButton.extended(
              onPressed: () => editCleaningTask(context, CleaningTask(date: ymd(today()), text: '')),
              backgroundColor: MM.ink,
              foregroundColor: MM.cream,
              icon: const Icon(Icons.add),
              label: const Text('Indicación'),
            ),
      body: StreamView<List<CleaningEvent>>(
        stream: Repo.instance.housekeeping(),
        builder: (context, events) => StreamView<Set<String>>(
          stream: Repo.instance.cleaningDone(),
          builder: (context, done) => StreamView<List<CleaningTask>>(
            stream: Repo.instance.cleaningTasks(),
            builder: (context, tasks) => _body(context, events, done, tasks, canEdit),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<CleaningEvent> events, Set<String> done, List<CleaningTask> tasks, bool canEdit) {
    final t = ymd(today());
    final late = tasks.where((k) => !k.done && k.date.compareTo(t) < 0).toList();
    // Los próximos 10 días con algo para hacer.
    final days = {
      ...events.where((e) => e.date.compareTo(t) >= 0).map((e) => e.date),
      ...tasks.where((k) => k.date.compareTo(t) >= 0).map((k) => k.date),
    }.toList()
      ..sort();

    return PageBody(maxWidth: 900, children: [
      const SectionHead(sticker: 'Limpieza', title: 'Cabañas para preparar'),
      const Text('Tocá el círculo cuando la cabaña quede lista. El armado de camas lo carga quien toma la reserva.', style: TextStyle(color: MM.inkSoft)),
      if (late.isNotEmpty) ...[
        _dayHead('Quedaron pendientes'),
        Card(child: Column(children: [for (final k in late) _TaskTile(task: k, canEdit: canEdit)])),
      ],
      for (final d in days.take(10)) ...[
        _dayHead(_dayLabel(d)),
        Card(
          child: Column(children: [
            for (final (i, cabin) in ({for (final e in events.where((e) => e.date == d)) e.cabin}.toList()..sort()).indexed) ...[
              if (i > 0) const Divider(height: 1),
              _CabinTile(events: events.where((e) => e.date == d && e.cabin == cabin).toList(), done: done, canEdit: canEdit),
            ],
            for (final k in tasks.where((k) => k.date == d)) _TaskTile(task: k, canEdit: canEdit),
          ]),
        ),
      ],
      if (days.isEmpty && late.isEmpty)
        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No hay salidas ni llegadas en los próximos días.'))),
    ]);
  }

  static String _dayLabel(String d) {
    final t = today();
    final day = parseYmd(d);
    final prefix = day == t ? 'Hoy · ' : (day == t.add(const Duration(days: 1)) ? 'Mañana · ' : '');
    return '$prefix${fmtDay(day)}';
  }

  static Widget _dayHead(String text) =>
      Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 8), child: Text(text.toUpperCase(), style: MM.label()));
}

/// Una cabaña en un día: si se van, si llegan y cómo dejarla.
class _CabinTile extends StatelessWidget {
  const _CabinTile({required this.events, required this.done, required this.canEdit});
  final List<CleaningEvent> events;
  final Set<String> done;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final out = events.where((e) => !e.arrival).firstOrNull;
    final arrival = events.where((e) => e.arrival).firstOrNull;
    final isDone = events.every((e) => done.contains(e.key));
    final lines = <Widget>[
      if (out != null) const Text('Se van: limpiar a fondo', style: TextStyle(fontWeight: FontWeight.w600)),
      if (arrival != null) ...[
        Text(
          [
            'Llegan${arrival.people != null ? ' ${arrival.people} personas' : ''}',
            if (arrival.nights != null) '${arrival.nights} ${arrival.nights == 1 ? 'noche' : 'noches'}',
            if (arrival.tentative) 'a confirmar',
          ].join(' · '),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          arrival.beds == null ? 'Camas: preguntar cómo armarlas' : 'Camas: ${arrival.beds}',
          style: TextStyle(fontWeight: FontWeight.w800, color: arrival.beds == null ? MM.canyon : MM.forest),
        ),
        if (arrival.crib || arrival.pets) Text([if (arrival.crib) 'Poner cuna', if (arrival.pets) 'Vienen con mascota'].join(' · ')),
        if ((arrival.note ?? '').isNotEmpty) Text(arrival.note!, style: const TextStyle(fontStyle: FontStyle.italic)),
      ],
    ];
    return ListTile(
      leading: IconButton(
        tooltip: isDone ? 'Volver a pendiente' : 'Marcar lista',
        icon: Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? MM.forest : MM.canyon),
        onPressed: !canEdit
            ? null
            : () async {
                for (final e in events) {
                  await Repo.instance.setCleaningDone(e, !isDone);
                }
              },
      ),
      title: Text('Cabaña ${events.first.cabin}', style: MM.display(18)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
      isThreeLine: lines.length > 1,
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.canEdit});
  final CleaningTask task;
  final bool canEdit;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: IconButton(
          tooltip: task.done ? 'Volver a pendiente' : 'Marcar hecha',
          icon: Icon(task.done ? Icons.check_circle : Icons.radio_button_unchecked, color: task.done ? MM.forest : MM.canyon),
          onPressed: !canEdit ? null : () => Repo.instance.saveCleaningTask(task..done = !task.done),
        ),
        title: Text(task.text, style: TextStyle(fontWeight: FontWeight.w700, decoration: task.done ? TextDecoration.lineThrough : null)),
        subtitle: Text([
          if (task.cabin != null) 'Cabaña ${task.cabin}' else 'General',
          if (task.date.compareTo(ymd(today())) < 0) 'del ${fmtShort(parseYmd(task.date))}',
          if (task.createdName != null) 'pidió ${task.createdName}',
        ].join(' · ')),
        trailing: const Icon(Icons.checklist, color: MM.rioDeep),
        onTap: canEdit ? () => editCleaningTask(context, task) : null,
      );
}

/// Alta o edición de una indicación para las mucamas.
Future<void> editCleaningTask(BuildContext context, CleaningTask t) async {
  final text = TextEditingController(text: t.text);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheet).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t.id == null ? 'Nueva indicación' : 'Indicación', style: MM.display(26)),
          const SizedBox(height: 16),
          TextField(
            controller: text,
            autofocus: t.id == null,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(labelText: 'Qué hay que hacer', hintText: 'Repasar vidrios, cambiar cortinas…'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: t.cabin,
            decoration: const InputDecoration(labelText: 'Dónde'),
            items: [
              const DropdownMenuItem(value: null, child: Text('General')),
              for (final c in defaultCabins) DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => t.cabin = v,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: sheet, initialDate: parseYmd(t.date), firstDate: DateTime(2024), lastDate: DateTime(2035));
              if (d != null) setSheet(() => t.date = ymd(d));
            },
            child: InputDecorator(decoration: const InputDecoration(labelText: 'Para cuándo'), child: Text(fmtDay(parseYmd(t.date)))),
          ),
          const SizedBox(height: 20),
          Row(children: [
            if (t.id != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(sheet);
                  await Repo.instance.deleteCleaningTask(t.id!);
                },
                child: const Text('Borrar', style: TextStyle(color: MM.canyon)),
              ),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                if (text.text.trim().isEmpty) return;
                Navigator.pop(sheet);
                await Repo.instance.saveCleaningTask(t..text = text.text.trim());
              },
              child: const Text('Guardar'),
            ),
          ]),
        ]),
      ),
    ),
  );
}

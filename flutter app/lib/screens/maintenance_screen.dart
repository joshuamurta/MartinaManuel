import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repo.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'purchases_screen.dart';

/// Historial de arreglos por cabaña y por servicio (piletas, jacuzzi, parque…),
/// y tareas con responsable y fecha.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  String? _area; // null = todo
  bool? _mine; // null = según el rol: el staff arranca viendo sólo lo suyo

  List<String> get _areas => [for (final c in defaultCabins) 'cabin-${c.id}', ...maintenanceAreas.keys];

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final perms = session.perms;
    final canEdit = perms.canEdit('mantenimiento');
    final mine = _mine ?? !perms.can('reservas');
    final uid = session.profile?.uid;
    return Scaffold(
      floatingActionButton: !canEdit
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(context, MaintenanceItem(area: _area ?? 'general', title: '', date: ymd(today()))),
              backgroundColor: MM.ink,
              foregroundColor: MM.cream,
              icon: const Icon(Icons.add),
              label: const Text('Anotar'),
            ),
      body: StreamView<List<MaintenanceItem>>(
        stream: Repo.instance.maintenance(),
        builder: (context, all) {
          final items = all.where((m) => (_area == null || m.area == _area) && (!mine || m.isFor(uid))).toList();
          // Primero lo que tiene fecha (lo más urgente arriba), después el resto.
          final open = items.where((m) => m.isOpen).toList()
            ..sort((a, b) => (a.dueDate ?? '9999').compareTo(b.dueDate ?? '9999'));
          final done = items.where((m) => m.status == MStatus.hecho).toList();
          final year = '${today().year}';
          final spent = done.where((m) => m.date.startsWith(year)).fold<num>(0, (a, m) => a + (m.cost ?? 0));

          return PageBody(children: [
            const SectionHead(sticker: 'Mantenimiento', title: 'Arreglos e historial'),
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: const Text('Mis tareas'),
                    selected: mine,
                    onSelected: (v) => setState(() => _mine = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: const Text('Todo'), selected: _area == null, onSelected: (_) => setState(() => _area = null)),
                ),
                for (final a in _areas)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${areaLabel(a)} (${all.where((m) => m.area == a).length})'),
                      selected: _area == a,
                      onSelected: (_) => setState(() => _area = a),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              InfoChip('${open.length} pendientes', icon: Icons.pending_actions, color: open.isEmpty ? MM.sauce : MM.sand),
              if (perms.costs) InfoChip('Gastado en $year: ${fmtMoney(spent)}', icon: Icons.payments_outlined),
            ]),
            _group('Pendiente', open, canEdit: canEdit, costs: perms.costs),
            _group('Historial', done, canEdit: canEdit, costs: perms.costs),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Todavía no hay nada anotado. Tocá "Anotar" para cargar un arreglo o un service.')),
              ),
          ]);
        },
      ),
    );
  }

  Widget _group(String title, List<MaintenanceItem> items, {required bool canEdit, required bool costs}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 8), child: Text(title.toUpperCase(), style: MM.label())),
      Card(
        child: Column(children: [
          for (final (i, m) in items.indexed) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              onTap: canEdit ? () => _edit(context, m) : null,
              leading: IconButton(
                tooltip: m.status == MStatus.hecho ? 'Volver a pendiente' : 'Marcar hecho',
                icon: Icon(
                  m.status == MStatus.hecho ? Icons.check_circle : (m.status == MStatus.enCurso ? Icons.autorenew : Icons.radio_button_unchecked),
                  color: m.status == MStatus.hecho ? MM.forest : MM.canyon,
                ),
                onPressed: !canEdit ? null : () => Repo.instance.toggleMaintenance(m),
              ),
              title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text([
                areaLabel(m.area),
                if (m.isOpen && m.dueDate != null) _dueText(m.dueDate!) else fmtDay(parseYmd(m.date)),
                if (m.assignedName != null) '→ ${m.assignedName}',
                if (m.repeatDays != null) 'cada ${m.repeatDays} ${m.repeatDays == 1 ? 'día' : 'días'}',
                if (m.kind != 'reparacion') m.kind == 'preventivo' ? 'Preventivo' : 'Mejora',
                if ((m.provider ?? '').isNotEmpty) m.provider!,
                if ((m.description ?? '').isNotEmpty) m.description!,
              ].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: !costs || m.cost == null ? null : Text(fmtMoney(m.cost), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    ]);
  }

  static String _dueText(String due) {
    final t = ymd(today());
    if (due == t) return 'Para hoy';
    if (due.compareTo(t) < 0) return 'Atrasada (${fmtShort(parseYmd(due))})';
    return 'Para el ${fmtDay(parseYmd(due))}';
  }

  Future<void> _edit(BuildContext context, MaintenanceItem m) async {
    final title = TextEditingController(text: m.title);
    final desc = TextEditingController(text: m.description ?? '');
    final cost = TextEditingController(text: m.cost?.round().toString() ?? '');
    final provider = TextEditingController(text: m.provider ?? '');
    final perms = SessionScope.of(context).perms;
    final wasOpen = m.isOpen;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheet).bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(m.id == null ? 'Anotar arreglo' : 'Editar', style: MM.display(26)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: m.area,
                decoration: const InputDecoration(labelText: 'Dónde'),
                items: [for (final a in _areas) DropdownMenuItem(value: a, child: Text(areaLabel(a)))],
                onChanged: (v) => m.area = v ?? m.area,
              ),
              const SizedBox(height: 12),
              TextField(controller: title, autofocus: m.id == null, decoration: const InputDecoration(labelText: 'Qué pasó / qué se hizo', hintText: 'Cambio de bomba, pérdida en el baño…')),
              const SizedBox(height: 12),
              TextField(controller: desc, maxLines: 3, minLines: 1, decoration: const InputDecoration(labelText: 'Detalle')),
              const SizedBox(height: 12),
              Row(children: [
                if (perms.costs) ...[
                  Expanded(
                    child: TextField(
                      controller: cost,
                      enabled: perms.editCosts,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Costo', prefixText: r'$ '),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(child: TextField(controller: provider, decoration: const InputDecoration(labelText: 'Quién lo hizo'))),
              ]),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: sheet, initialDate: parseYmd(m.date), firstDate: DateTime(2019), lastDate: DateTime(2035));
                  if (d != null) setSheet(() => m.date = ymd(d));
                },
                child: InputDecorator(decoration: const InputDecoration(labelText: 'Fecha'), child: Text(fmtDay(parseYmd(m.date)))),
              ),
              const SizedBox(height: 12),
              _Assignee(m: m),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                          context: sheet, initialDate: m.dueDate == null ? today() : parseYmd(m.dueDate!), firstDate: DateTime(2024), lastDate: DateTime(2035));
                      if (d != null) setSheet(() => m.dueDate = ymd(d));
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Para cuándo',
                        suffixIcon: m.dueDate == null
                            ? null
                            : IconButton(tooltip: 'Sin fecha', icon: const Icon(Icons.close), onPressed: () => setSheet(() => m.dueDate = null)),
                      ),
                      child: Text(m.dueDate == null ? 'Sin fecha' : fmtDay(parseYmd(m.dueDate!))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: const [1, 2, 3, 7, 15, 30].contains(m.repeatDays) ? m.repeatDays : null,
                    decoration: const InputDecoration(labelText: 'Se repite'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No')),
                      for (final d in const [1, 2, 3, 7, 15, 30]) DropdownMenuItem(value: d, child: Text(d == 1 ? 'Todos los días' : 'Cada $d días')),
                    ],
                    onChanged: (v) => setSheet(() {
                      m.repeatDays = v;
                      if (v != null) m.dueDate ??= ymd(today());
                    }),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in const {'reparacion': 'Reparación', 'preventivo': 'Preventivo / service', 'mejora': 'Mejora'}.entries)
                  ChoiceChip(label: Text(k.value), selected: m.kind == k.key, onSelected: (_) => setSheet(() => m.kind = k.key)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in MStatus.values)
                  ChoiceChip(label: Text(mStatusLabel(s)), selected: m.status == s, onSelected: (_) => setSheet(() => m.status = s)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                if (m.id != null && perms.delete)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(sheet);
                      await Repo.instance.deleteMaintenance(m.id!);
                    },
                    child: const Text('Eliminar', style: TextStyle(color: MM.canyon)),
                  ),
                if (m.id != null && perms.can('compras'))
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheet);
                      requestPurchase(context, forItem: m);
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Pedir material'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    if (title.text.trim().isEmpty) return;
                    m
                      ..title = title.text.trim()
                      ..description = desc.text.trim()
                      ..cost = perms.editCosts ? num.tryParse(cost.text) : m.cost
                      ..provider = provider.text.trim();
                    Navigator.pop(sheet);
                    if (wasOpen && !m.isOpen && m.repeatDays != null) {
                      // Terminada desde acá: igual que con el círculo, si se repite queda la próxima.
                      m.status = MStatus.pendiente;
                      await Repo.instance.toggleMaintenance(m);
                    } else {
                      await Repo.instance.saveMaintenance(m);
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A quién le toca. Lista a quienes pueden editar mantenimiento.
class _Assignee extends StatefulWidget {
  const _Assignee({required this.m});
  final MaintenanceItem m;

  @override
  State<_Assignee> createState() => _AssigneeState();
}

class _AssigneeState extends State<_Assignee> {
  late final _users = Repo.instance.users();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppUser>>(
        stream: _users,
        builder: (context, snap) {
          final m = widget.m;
          final people = (snap.data ?? []).where((u) => u.active && u.perms.canEdit('mantenimiento')).toList();
          if (m.assignedTo != null && !people.any((u) => u.uid == m.assignedTo)) {
            people.add(AppUser(uid: m.assignedTo!, email: '', name: m.assignedName ?? '?', role: Role.staff, active: true));
          }
          return DropdownButtonFormField<String?>(
            key: ValueKey(people.length),
            initialValue: m.assignedTo,
            decoration: const InputDecoration(labelText: 'Quién lo tiene que hacer'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Cualquiera')),
              for (final u in people) DropdownMenuItem(value: u.uid, child: Text(u.name)),
            ],
            onChanged: (v) {
              m.assignedTo = v;
              m.assignedName = people.where((u) => u.uid == v).firstOrNull?.name;
            },
          );
        },
      );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repo.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Reemplaza las hojas CAJA, BANCO FRANCES, MERC. PAGO y GASTOS MENSUALES.
class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  DateTime _month = DateTime(today().year, today().month);
  String? _account;

  @override
  Widget build(BuildContext context) {
    final canEdit = SessionScope.of(context).perms.canEdit('caja');
    return Scaffold(
      floatingActionButton: !canEdit
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(context, null),
              backgroundColor: MM.ink,
              foregroundColor: MM.cream,
              icon: const Icon(Icons.add),
              label: const Text('Movimiento'),
            ),
      body: StreamView<List<Movement>>(
        stream: Repo.instance.movements(),
        builder: (context, all) {
          final balances = <String, num>{for (final k in accounts.keys) k: 0};
          for (final m in all) {
            balances[m.account] = (balances[m.account] ?? 0) + m.amount;
          }
          final prefix = ymd(_month).substring(0, 7);
          final month = all.where((m) => m.date.startsWith(prefix) && (_account == null || m.account == _account)).toList();
          final income = month.where((m) => m.isIncome).fold<num>(0, (a, m) => a + m.amount);
          final expense = month.where((m) => !m.isIncome).fold<num>(0, (a, m) => a - m.amount);
          final byCategory = <String, num>{};
          for (final m in month.where((m) => !m.isIncome)) {
            byCategory[m.category] = (byCategory[m.category] ?? 0) - m.amount;
          }
          final cats = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

          return PageBody(children: [
            const SectionHead(sticker: 'Caja', title: 'Cuentas y gastos'),
            SizedBox(
              height: 92,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final e in accounts.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _AccountCard(
                      label: e.value,
                      value: balances[e.key] ?? 0,
                      usd: e.key == 'usd',
                      selected: _account == e.key,
                      onTap: () => setState(() => _account = _account == e.key ? null : e.key),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              IconButton.filledTonal(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.arrow_back)),
              Expanded(child: Center(child: Text(fmtMonth(_month), style: MM.display(22)))),
              IconButton.filledTonal(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.arrow_forward)),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              InfoChip('Ingresos ${fmtMoney(income)}', icon: Icons.arrow_downward, color: MM.sauce, fg: MM.forest),
              InfoChip('Egresos ${fmtMoney(expense)}', icon: Icons.arrow_upward, color: MM.sand, fg: MM.canyon),
              InfoChip('Resultado ${fmtMoney(income - expense)}'),
              if (_account != null) InfoChip('Sólo ${accounts[_account]}', icon: Icons.filter_alt_outlined),
            ]),
            if (cats.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 8), child: Text('GASTOS DEL MES POR RUBRO', style: MM.label())),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    for (final c in cats)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          SizedBox(width: 170, child: Text(c.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: c.value / cats.first.value,
                                minHeight: 10,
                                backgroundColor: MM.cream,
                                color: MM.canyon.withValues(alpha: .7),
                              ),
                            ),
                          ),
                          SizedBox(width: 120, child: Text(fmtMoney(c.value), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                        ]),
                      ),
                  ]),
                ),
              ),
            ],
            Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 8), child: Text('MOVIMIENTOS', style: MM.label())),
            if (month.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Text('No hay movimientos este mes.'))
            else
              Card(
                child: Column(children: [
                  for (final (i, m) in month.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      onTap: canEdit ? () => _edit(context, m) : null,
                      leading: Icon(m.isIncome ? Icons.south_west : Icons.north_east, color: m.isIncome ? MM.forest : MM.canyon),
                      title: Text(m.detail, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${fmtShort(parseYmd(m.date))} · ${accounts[m.account] ?? m.account} · ${m.category}'),
                      trailing: Text(
                        fmtMoney(m.amount),
                        style: TextStyle(fontWeight: FontWeight.w800, color: m.isIncome ? MM.forest : MM.canyon),
                      ),
                    ),
                  ],
                ]),
              ),
          ]);
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, Movement? existing) async {
    final m = existing ?? Movement(date: ymd(today()), detail: '', amount: 0, account: _account ?? 'caja', category: 'Otros');
    var income = existing?.isIncome ?? false;
    final amount = TextEditingController(text: existing == null ? '' : m.amount.abs().round().toString());
    final detail = TextEditingController(text: m.detail);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          final cats = income ? incomeCategories : [...expenseCategories, 'Saldo inicial'];
          if (!cats.contains(m.category)) m.category = cats.first;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheet).bottom + 20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(existing == null ? 'Nuevo movimiento' : 'Editar movimiento', style: MM.display(26)),
                if (m.reservationId != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Viene de un pago de reserva: para cambiarlo, editá el pago en la reserva.', style: TextStyle(color: MM.canyon)),
                  ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [ButtonSegment(value: false, label: Text('Egreso')), ButtonSegment(value: true, label: Text('Ingreso'))],
                  selected: {income},
                  onSelectionChanged: (s) => setSheet(() => income = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  autofocus: existing == null,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Monto', prefixText: r'$ '),
                ),
                const SizedBox(height: 12),
                TextField(controller: detail, decoration: const InputDecoration(labelText: 'Detalle', hintText: 'Edemsa, ferretería, sueldo…')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: m.account,
                  decoration: const InputDecoration(labelText: 'Cuenta'),
                  items: [for (final e in accounts.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => m.account = v ?? m.account,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(income),
                  initialValue: m.category,
                  decoration: const InputDecoration(labelText: 'Rubro'),
                  items: [for (final c in cats) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) => m.category = v ?? m.category,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: sheet, initialDate: parseYmd(m.date), firstDate: DateTime(2019), lastDate: DateTime(2035));
                    if (d != null) setSheet(() => m.date = ymd(d));
                  },
                  child: InputDecorator(decoration: const InputDecoration(labelText: 'Fecha'), child: Text(fmtDay(parseYmd(m.date)))),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  if (existing != null && m.reservationId == null)
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(sheet);
                        await Repo.instance.deleteMovement(m.id!);
                      },
                      child: const Text('Eliminar', style: TextStyle(color: MM.canyon)),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: m.reservationId != null
                        ? null
                        : () async {
                            final v = num.tryParse(amount.text);
                            if (v == null || v <= 0 || detail.text.trim().isEmpty) return;
                            m
                              ..amount = income ? v : -v
                              ..detail = detail.text.trim();
                            Navigator.pop(sheet);
                            await Repo.instance.saveMovement(m);
                          },
                    child: const Text('Guardar'),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.label, required this.value, required this.selected, required this.onTap, this.usd = false});
  final String label;
  final num value;
  final bool selected, usd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? MM.ink : MM.paper,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: 190,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: MM.ink.withValues(alpha: .08))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label.toUpperCase(), style: MM.label(color: selected ? MM.rio : MM.forest), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(usd ? 'u\$s ${value.round()}' : fmtMoney(value), style: MM.display(22, color: selected ? MM.cream : MM.ink)),
              ),
            ]),
          ),
        ),
      );
}

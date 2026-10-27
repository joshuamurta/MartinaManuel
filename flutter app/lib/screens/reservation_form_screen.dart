import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/repo.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/payment_dialog.dart';

class ReservationFormScreen extends StatefulWidget {
  const ReservationFormScreen({super.key, this.id, this.cabin, this.checkIn, this.checkOut});
  final String? id;
  final int? cabin;
  final String? checkIn;
  final String? checkOut;

  @override
  State<ReservationFormScreen> createState() => _ReservationFormScreenState();
}

class _ReservationFormScreenState extends State<ReservationFormScreen> {
  final _form = GlobalKey<FormState>();
  Reservation? _r;
  final _removed = <Payment>[];
  List<Reservation> _conflicts = [];
  bool _saving = false;

  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _people = TextEditingController();
  final _total = TextEditingController();
  final _price = TextEditingController();
  final _usd = TextEditingController();
  final _invoice = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.id == null) {
      final inD = widget.checkIn ?? ymd(today());
      final outD = widget.checkOut ?? ymd(parseYmd(inD).add(const Duration(days: 1)));
      _set(Reservation(name: '', cabins: [?widget.cabin], checkIn: inD, checkOut: outD, channel: 'whatsapp', status: ResStatus.consulta));
    } else {
      Repo.instance.reservation(widget.id!).first.then((r) {
        if (r != null && mounted) setState(() => _set(r));
      });
    }
  }

  void _set(Reservation r) {
    _r = r;
    _name.text = r.name;
    _contact.text = r.contact ?? '';
    _email.text = r.email ?? '';
    _people.text = r.people?.toString() ?? '';
    _total.text = r.total?.round().toString() ?? '';
    _price.text = r.nightlyPrice?.round().toString() ?? '';
    _usd.text = r.balanceUsd?.toString() ?? '';
    _invoice.text = r.invoiceNo ?? '';
    _notes.text = r.notes ?? '';
    _checkConflicts();
  }

  Future<void> _checkConflicts() async {
    final r = _r;
    if (r == null || r.cabins.isEmpty) {
      setState(() => _conflicts = []);
      return;
    }
    final c = await Repo.instance.conflictsFor(r);
    if (mounted) setState(() => _conflicts = c);
  }

  String? _optText(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final r = _r!;
    if (!_form.currentState!.validate()) return;
    if (r.cabins.isEmpty) {
      toast(context, 'Elegí al menos una cabaña.');
      return;
    }
    r
      ..name = _name.text.trim()
      ..contact = _optText(_contact)
      ..email = _optText(_email)
      ..people = int.tryParse(_people.text)
      ..total = num.tryParse(_total.text)
      ..nightlyPrice = num.tryParse(_price.text)
      ..balanceUsd = num.tryParse(_usd.text.replaceAll(',', '.'))
      ..invoiceNo = _optText(_invoice)
      ..notes = _optText(_notes);
    if (r.isBlock && r.name.isEmpty) r.name = 'Bloqueado';

    setState(() => _saving = true);
    try {
      final conflicts = await Repo.instance.conflictsFor(r);
      if (!mounted) return;
      if (conflicts.isNotEmpty &&
          !await confirm(
            context,
            'Se superpone',
            'En esas noches ya está: ${conflicts.map((c) => '${c.name} (${c.cabinsLabel}, ${fmtShort(c.inDate)}–${fmtShort(c.outDate)})').join('; ')}.\n\n¿Guardar igual?',
            ok: 'Guardar igual',
            danger: true,
          )) {
        return;
      }
      final id = await Repo.instance.saveReservation(r, removedPayments: _removed);
      if (!mounted) return;
      toast(context, 'Reserva guardada. La web ya muestra esas noches ocupadas.');
      if (widget.id == null) {
        context.pushReplacement('/reservas/$id');
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) toast(context, 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final money = SessionScope.of(context).perms.editMoney;
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'Nueva reserva' : 'Editar reserva')),
      bottomNavigationBar: r == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: MM.cream))
                      : const Text('Guardar'),
                ),
              ),
            ),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : SettingsBuilder(
              builder: (context, settings) => Form(
                key: _form,
                child: PageBody(maxWidth: 820, children: [
                  _section('Estado'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in [ResStatus.consulta, ResStatus.confirmada, ResStatus.bloqueo, if (widget.id != null) ResStatus.cancelada])
                      ChoiceChip(
                        label: Text(statusLabel(s)),
                        selected: r.status == s,
                        onSelected: (_) {
                          setState(() => r.status = s);
                          _checkConflicts();
                        },
                      ),
                  ]),
                  _section('Fechas y cabañas'),
                  _DatesField(
                    r: r,
                    onChanged: (a, b) {
                      setState(() {
                        r.checkIn = ymd(a);
                        r.checkOut = ymd(b);
                      });
                      _checkConflicts();
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in settings.cabins)
                      FilterChip(
                        avatar: Text('${c.id}', style: MM.display(14)),
                        label: Text('${c.maxPeople}p${money && c.price != null ? ' · ${fmtMoney(c.price)}' : ''}'),
                        selected: r.cabins.contains(c.id),
                        onSelected: (on) {
                          setState(() => r.cabins = on ? ([...r.cabins, c.id]..sort()) : r.cabins.where((x) => x != c.id).toList());
                          _checkConflicts();
                        },
                      ),
                  ]),
                  if (_conflicts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Ojo: se superpone con ${_conflicts.map((c) => '${c.name} (${c.cabinsLabel})').join(', ')}.',
                        style: const TextStyle(color: MM.canyon, fontWeight: FontWeight.w700),
                      ),
                    ),
                  _section(r.isBlock ? 'Motivo' : 'Huésped'),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: r.isBlock ? 'Motivo (pintura, uso propio…)' : 'Nombre y apellido'),
                    validator: (v) => !r.isBlock && (v ?? '').trim().isEmpty ? 'Falta el nombre' : null,
                  ),
                  if (!r.isBlock) ...[
                    const SizedBox(height: 12),
                    _row([
                      TextFormField(
                        controller: _contact,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp', hintText: '11 4149-5810'),
                      ),
                      TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                    ]),
                    const SizedBox(height: 12),
                    _row([
                      TextFormField(
                        controller: _people,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Personas',
                          helperText: r.cabins.isEmpty ? null : 'Capacidad: ${r.cabins.fold<int>(0, (a, c) => a + settings.cabin(c).maxPeople)}',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: channels.containsKey(r.channel) ? r.channel : null,
                        decoration: const InputDecoration(labelText: 'Cómo nos conoció'),
                        items: [for (final e in channels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                        onChanged: (v) => r.channel = v,
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      FilterChip(label: const Text('Desayuno'), selected: r.breakfast, onSelected: (v) => setState(() => r.breakfast = v)),
                      FilterChip(label: const Text('Mascota'), selected: r.pets, onSelected: (v) => setState(() => r.pets = v)),
                      FilterChip(label: const Text('Cuna'), selected: r.crib, onSelected: (v) => setState(() => r.crib = v)),
                    ]),
                  ],
                  if (!r.isBlock && money) ...[
                    _section('Importe'),
                    _row([
                      TextFormField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Precio por noche', prefixText: r'$ '),
                      ),
                      TextFormField(
                        controller: _total,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Total', prefixText: r'$ '),
                      ),
                    ]),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('Calcular con la tarifa'),
                        onPressed: () => _suggest(settings),
                      ),
                    ),
                    _row([
                      TextFormField(controller: _invoice, decoration: const InputDecoration(labelText: 'Factura Nº')),
                      TextFormField(
                        controller: _usd,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Saldo en dólares (si aplica)', prefixText: r'u$s '),
                      ),
                    ]),
                    _section('Pagos'),
                    for (final p in r.payments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_outline, color: MM.forest),
                        title: Text(fmtMoney(p.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text([fmtDay(parseYmd(p.date)), if (p.account != null) accounts[p.account] ?? '', p.note ?? ''].where((s) => s.isNotEmpty).join(' · ')),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _removed.add(p);
                            r.payments = r.payments.where((x) => x.id != p.id).toList();
                          }),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar pago (seña, saldo…)'),
                        onPressed: () async {
                          final total = num.tryParse(_total.text);
                          final p = await showPaymentDialog(context, suggested: total == null ? null : total - r.paid);
                          if (p == null) return;
                          setState(() {
                            r.payments = [...r.payments, p];
                            if (r.status == ResStatus.consulta) r.status = ResStatus.confirmada;
                          });
                        },
                      ),
                    ),
                  ],
                  _section('Notas'),
                  TextFormField(
                    controller: _notes,
                    maxLines: 4,
                    minLines: 2,
                    decoration: const InputDecoration(hintText: 'Camas individuales, llegan tarde, aniversario…'),
                  ),
                ]),
              ),
            ),
    );
  }

  void _suggest(Settings s) {
    final r = _r!;
    final prices = [for (final c in r.cabins) s.cabin(c).price];
    if (prices.isEmpty || prices.any((p) => p == null)) {
      toast(context, 'Cargá la tarifa de las cabañas en Ajustes para calcular.');
      return;
    }
    final perNight = prices.fold<num>(0, (a, p) => a + p!);
    setState(() {
      _price.text = perNight.round().toString();
      _total.text = (perNight * r.nights).round().toString();
    });
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.fromLTRB(2, 22, 2, 10), child: Text(t.toUpperCase(), style: MM.label()));

  Widget _row(List<Widget> children) => LayoutBuilder(
        builder: (context, box) => box.maxWidth < 520
            ? Column(children: [for (final (i, c) in children.indexed) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 12), child: c)])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final (i, c) in children.indexed) Expanded(child: Padding(padding: EdgeInsets.only(left: i == 0 ? 0 : 12), child: c)),
              ]),
      );
}

class _DatesField extends StatelessWidget {
  const _DatesField({required this.r, required this.onChanged});
  final Reservation r;
  final void Function(DateTime checkIn, DateTime checkOut) onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2019),
            lastDate: DateTime(today().year + 3),
            initialDateRange: DateTimeRange(start: r.inDate, end: r.outDate),
            helpText: 'Llegada y salida',
            saveText: 'Listo',
          );
          if (range != null && range.end.isAfter(range.start)) onChanged(dateOnly(range.start), dateOnly(range.end));
        },
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Llegada → salida', suffixIcon: Icon(Icons.edit_calendar_outlined)),
          child: Text('${fmtDay(r.inDate)} → ${fmtDay(r.outDate)}  ·  ${r.nights} ${r.nights == 1 ? 'noche' : 'noches'}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}

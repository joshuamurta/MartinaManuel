import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/repo.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/payment_dialog.dart';

class ReservationDetailScreen extends StatelessWidget {
  const ReservationDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return SettingsBuilder(
      builder: (context, settings) => StreamView<Reservation?>(
        stream: Repo.instance.reservation(id),
        builder: (context, r) {
          if (r == null) {
            return Scaffold(appBar: AppBar(), body: const Center(child: Text('Esta reserva ya no existe.')));
          }
          final c = reservationColors(r);
          return Scaffold(
            appBar: AppBar(
              title: Text(r.isBlock ? 'Bloqueo' : 'Reserva'),
              actions: [
                if (!r.isBlock)
                  IconButton(tooltip: 'WhatsApp', icon: const Icon(Icons.chat_outlined), onPressed: () => showWhatsAppPicker(context, r, settings)),
                IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/reservas/${r.id}/editar')),
                PopupMenuButton<String>(
                  onSelected: (v) => _menu(context, v, r),
                  itemBuilder: (_) => [
                    if (r.status != ResStatus.cancelada) const PopupMenuItem(value: 'cancel', child: Text('Cancelar reserva')),
                    if (r.status == ResStatus.cancelada) const PopupMenuItem(value: 'restore', child: Text('Reactivar')),
                    if (session.isAdmin) const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: MM.canyon))),
                  ],
                ),
              ],
            ),
            body: PageBody(maxWidth: 820, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(r.name, style: MM.display(34))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(99)),
                  child: Text(reservationStateText(r), style: TextStyle(fontWeight: FontWeight.w800, color: c.fg)),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                InfoChip(r.cabinsLabel, icon: Icons.cottage_outlined),
                InfoChip('${fmtDay(r.inDate)} → ${fmtDay(r.outDate)}', icon: Icons.event),
                InfoChip('${r.nights} ${r.nights == 1 ? 'noche' : 'noches'}', icon: Icons.nights_stay_outlined),
                if (r.people != null) InfoChip('${r.people} personas', icon: Icons.people_outline),
                if (r.breakfast) const InfoChip('Desayuno', icon: Icons.free_breakfast_outlined),
                if (r.pets) const InfoChip('Mascota', icon: Icons.pets),
                if (r.crib) const InfoChip('Cuna', icon: Icons.crib_outlined),
                if (r.channel != null) InfoChip(channels[r.channel] ?? r.channel!, icon: Icons.campaign_outlined),
              ]),
              if (r.warnings.isNotEmpty) ...[const SizedBox(height: 16), _Warnings(r: r)],
              if (!r.isBlock) ...[
                const SizedBox(height: 16),
                _Money(r: r),
                const SizedBox(height: 16),
                _Contact(r: r, settings: settings),
              ],
              if ((r.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('NOTAS', style: MM.label()),
                      const SizedBox(height: 6),
                      SelectableText(r.notes!, style: const TextStyle(height: 1.5)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                [
                  if (r.reservedAt != null) 'Reservada el ${fmtDay(parseYmd(r.reservedAt!))}',
                  if (r.source != null) 'Origen: ${r.source}',
                ].join(' · '),
                style: const TextStyle(color: MM.inkSoft, fontSize: 12.5),
              ),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _menu(BuildContext context, String v, Reservation r) async {
    final repo = Repo.instance;
    switch (v) {
      case 'cancel':
        if (await confirm(context, 'Cancelar reserva', 'Las noches de ${r.name} quedan libres en el diagrama y en la web. Los pagos registrados se mantienen.',
            ok: 'Cancelar reserva', danger: true)) {
          r.status = ResStatus.cancelada;
          await repo.saveReservation(r);
        }
      case 'restore':
        final conflicts = await repo.conflictsFor(r..status = ResStatus.confirmada);
        if (!context.mounted) return;
        if (conflicts.isNotEmpty) {
          toast(context, 'No se puede reactivar: se superpone con ${conflicts.map((c) => c.name).join(', ')}.');
          return;
        }
        await repo.saveReservation(r);
      case 'delete':
        if (await confirm(context, 'Eliminar reserva', 'Se borra la reserva de ${r.name} y los cobros que se cargaron a la caja desde acá. No se puede deshacer.',
            ok: 'Eliminar', danger: true)) {
          await repo.deleteReservation(r);
          if (context.mounted) context.pop();
        }
    }
  }
}

class _Warnings extends StatelessWidget {
  const _Warnings({required this.r});
  final Reservation r;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: MM.sand, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.error_outline, color: MM.canyon),
            const SizedBox(width: 8),
            Expanded(child: Text('Revisar datos de la planilla', style: MM.display(18))),
          ]),
          const SizedBox(height: 8),
          for (final w in r.warnings) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $w')),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            OutlinedButton(onPressed: () => context.push('/reservas/${r.id}/editar'), child: const Text('Corregir')),
            FilledButton(
              onPressed: () async {
                r.warnings = [];
                await Repo.instance.saveReservation(r);
              },
              child: const Text('Marcar revisada'),
            ),
          ]),
        ]),
      );
}

class _Money extends StatelessWidget {
  const _Money({required this.r});
  final Reservation r;

  @override
  Widget build(BuildContext context) {
    final bal = r.balance;
    Widget cell(String label, String value, {Color? color}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: MM.label()),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: MM.display(22, color: color ?? MM.ink))),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            cell('Total', fmtMoney(r.total)),
            cell('Cobrado', fmtMoney(r.paid)),
            cell('Saldo', fmtMoney(bal), color: (bal ?? 0) > 0 ? MM.canyon : MM.forest),
          ]),
          if (r.nightlyPrice != null || r.balanceUsd != null || r.invoiceNo != null) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (r.nightlyPrice != null) InfoChip('${fmtMoney(r.nightlyPrice)} por noche'),
              if (r.balanceUsd != null) InfoChip('Saldo en dólares: u\$s ${r.balanceUsd}'),
              if (r.invoiceNo != null) InfoChip('Factura ${r.invoiceNo}${r.invoiceDate != null ? ' · ${fmtShort(parseYmd(r.invoiceDate!))}' : ''}', icon: Icons.receipt_long_outlined),
            ]),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Text('PAGOS', style: MM.label()),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                final p = await showPaymentDialog(context, suggested: bal != null && bal > 0 ? bal : null);
                if (p == null) return;
                r.payments = [...r.payments, p];
                if (r.status == ResStatus.consulta) r.status = ResStatus.confirmada;
                await Repo.instance.saveReservation(r);
              },
              icon: const Icon(Icons.add),
              label: const Text('Registrar pago'),
            ),
          ]),
          if (r.payments.isEmpty) const Text('Todavía no hay pagos.', style: TextStyle(color: MM.inkSoft)),
          for (final p in r.payments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.check_circle_outline, color: MM.forest),
              title: Text(fmtMoney(p.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text([
                fmtDay(parseYmd(p.date)),
                if (p.account != null) accounts[p.account] ?? p.account!,
                if ((p.note ?? '').isNotEmpty) p.note!,
              ].join(' · ')),
              trailing: IconButton(
                tooltip: 'Quitar pago',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () async {
                  if (!await confirm(context, 'Quitar pago', 'Se quita el pago de ${fmtMoney(p.amount)}${p.account != null ? ' y su ingreso en la caja' : ''}.',
                      ok: 'Quitar', danger: true)) {
                    return;
                  }
                  r.payments = r.payments.where((x) => x.id != p.id).toList();
                  await Repo.instance.saveReservation(r, removedPayments: [p]);
                },
              ),
            ),
        ]),
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({required this.r, required this.settings});
  final Reservation r;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final phone = r.contact;
    final n = waNumber(phone);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CONTACTO', style: MM.label()),
          const SizedBox(height: 6),
          if ((phone ?? '').isEmpty && (r.email ?? '').isEmpty) const Text('Sin datos de contacto.', style: TextStyle(color: MM.inkSoft)),
          if ((phone ?? '').isNotEmpty) SelectableText(phone!, style: MM.display(20)),
          if ((r.email ?? '').isNotEmpty) SelectableText(r.email!),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => showWhatsAppPicker(context, r, settings),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('WhatsApp'),
            ),
            if (n != null)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:+$n')),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Llamar'),
              ),
            if ((r.email ?? '').isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('mailto:${r.email}')),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Email'),
              ),
          ]),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/repo.dart';
import '../models.dart';
import '../theme.dart';

/// StreamBuilder con estados de carga y error ya resueltos.
class StreamView<T> extends StatelessWidget {
  const StreamView({super.key, required this.stream, required this.builder, this.initialData});
  final Stream<T> stream;
  final T? initialData;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
        stream: stream,
        initialData: initialData,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudo cargar: ${snap.error}', style: const TextStyle(color: MM.canyon)),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return builder(context, snap.data as T);
        },
      );
}

/// Ajustes (cabañas, tarifas, feriados) con valores por defecto mientras cargan.
class SettingsBuilder extends StatelessWidget {
  const SettingsBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, Settings settings) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<Settings>(
        stream: Repo.instance.settings(),
        builder: (context, snap) => builder(context, snap.data ?? Settings.fromMap(null)),
      );
}

/// Color de la barra de una reserva en el diagrama y en las listas.
({Color bg, Color fg}) reservationColors(Reservation r) {
  if (r.isBlock) return (bg: const Color(0xFFD9D6D0), fg: MM.inkSoft);
  if (r.status == ResStatus.cancelada) return (bg: const Color(0xFFF3D4C8), fg: MM.canyon);
  if (r.status == ResStatus.consulta) return (bg: MM.ocre, fg: MM.ink);
  final bal = r.balance;
  if (bal != null && bal > 0) return (bg: MM.alamo, fg: MM.forest); // confirmada, con saldo
  return (bg: MM.sauce, fg: MM.forest); // confirmada y paga
}

String reservationStateText(Reservation r) {
  if (r.status != ResStatus.confirmada) return statusLabel(r.status);
  final bal = r.balance;
  if (bal == null) return 'Confirmada';
  return bal > 0 ? 'Saldo ${fmtMoney(bal)}' : 'Pagada';
}

class StatusDot extends StatelessWidget {
  const StatusDot(this.r, {super.key, this.size = 12});
  final Reservation r;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: reservationColors(r).bg,
          shape: BoxShape.circle,
          border: Border.all(color: MM.ink.withValues(alpha: .25)),
        ),
      );
}

/// Referencias de color del diagrama.
class ColorLegend extends StatelessWidget {
  const ColorLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]);
    return Wrap(spacing: 14, runSpacing: 6, children: [
      item(MM.sauce, 'Pagada'),
      item(MM.alamo, 'Con saldo'),
      item(MM.ocre, 'Consulta / sin seña'),
      item(const Color(0xFFD9D6D0), 'Bloqueo'),
      item(MM.ocre.withValues(alpha: .25), 'Feriado'),
    ]);
  }
}

// ---------- WhatsApp ----------

/// Normaliza teléfonos como los de la planilla ("114149-5810", "261540-9673")
/// al formato internacional de celular argentino que usa wa.me.
String? waNumber(String? raw) {
  if (raw == null) return null;
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length < 8) return null;
  if (d.startsWith('54')) {
    d = d.substring(2);
    if (d.startsWith('9')) d = d.substring(1);
  }
  if (d.startsWith('0')) d = d.substring(1);
  // Sin el "15" de los celulares viejos: 11 15 4149-5810 → 11 4149-5810
  final m = RegExp(r'^(\d{2,4})15(\d{6,8})$').firstMatch(d);
  if (m != null && (m.group(1)!.length + m.group(2)!.length) == 10) d = m.group(1)! + m.group(2)!;
  return '549$d';
}

Future<void> openWhatsApp(BuildContext context, String? phone, String text) async {
  final n = waNumber(phone);
  final uri = Uri.parse('https://wa.me/${n ?? ''}?text=${Uri.encodeComponent(text)}');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.')));
  }
}

/// Mensajes que Eugenia hoy escribe a mano.
Map<String, String> whatsappTemplates(Reservation r, Settings s) {
  final first = r.name.split(' ').first;
  final fechas = 'del ${fmtDay(r.inDate)} al ${fmtDay(r.outDate)} (${r.nights} ${r.nights == 1 ? 'noche' : 'noches'})';
  final cabanas = r.cabins.map((c) => s.cabin(c).name).join(', ');
  final pago = (s.paymentInfo ?? '').trim();
  final bal = r.balance;
  return {
    'Confirmación': [
      '¡Hola $first! Te confirmamos la reserva en Cabañas Martina Manuel 🌿',
      '• $cabanas',
      '• Fechas: $fechas',
      if (r.people != null) '• Personas: ${r.people}',
      if (r.total != null) '• Total: ${fmtMoney(r.total)}',
      if (r.paid > 0) '• Recibimos: ${fmtMoney(r.paid)}',
      if (bal != null && bal > 0) '• Saldo: ${fmtMoney(bal)} (a abonar al ingresar)',
      if (r.breakfast) '• Con desayuno',
      '',
      'Check-in desde las ${s.checkInTime} y check-out hasta las ${s.checkOutTime}.',
      'Ruta 173 km 13,5, San Rafael. ¡Los esperamos!',
    ].join('\n'),
    'Pedir seña': [
      '¡Hola $first! Te paso los datos para reservar $cabanas $fechas.',
      if (r.total != null) 'El total es ${fmtMoney(r.total)}.',
      if (pago.isNotEmpty) ...['', pago],
      '',
      'Cuando hagas la transferencia mandame el comprobante y te confirmo. ¡Gracias!',
    ].join('\n'),
    'Recordatorio de llegada': [
      '¡Hola $first! Te esperamos el ${fmtDay(r.inDate)} en Cabañas Martina Manuel.',
      'El check-in es desde las ${s.checkInTime}. Estamos en Ruta 173 km 13,5: https://www.google.com/maps/search/?api=1&query=Caba%C3%B1as+Martina+Manuel+San+Rafael%2C+Mendoza',
      if (bal != null && bal > 0) 'Te recuerdo que queda un saldo de ${fmtMoney(bal)}.',
      'Cualquier cosa escribime por acá. ¡Buen viaje!',
    ].join('\n'),
    'Gracias y opinión': [
      '¡Hola $first! Gracias por elegirnos 💚 Esperamos que hayan disfrutado del río.',
      'Si tenés un minuto, nos ayuda mucho una opinión en Google: https://www.google.com/maps/search/?api=1&query=Caba%C3%B1as+Martina+Manuel',
      '¡Los esperamos de nuevo!',
    ].join('\n'),
  };
}

Future<void> showWhatsAppPicker(BuildContext context, Reservation r, Settings s) async {
  final templates = whatsappTemplates(r, s);
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Escribir a ${r.name}', style: MM.display(24)),
          if (waNumber(r.contact) == null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('No hay un teléfono válido: WhatsApp se abre para elegir el contacto.', style: TextStyle(color: MM.canyon)),
            ),
          const SizedBox(height: 12),
          for (final e in templates.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat_outlined, color: MM.rioDeep),
              title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(e.value, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(sheet);
                openWhatsApp(context, r.contact, e.value);
              },
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined, color: MM.rioDeep),
            title: const Text('Mensaje en blanco', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(sheet);
              openWhatsApp(context, r.contact, '');
            },
          ),
        ]),
      ),
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String body, {String ok = 'Sí', bool danger = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title, style: MM.display(22)),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: MM.canyon) : null,
            onPressed: () => Navigator.pop(d, true),
            child: Text(ok),
          ),
        ],
      ),
    ) ??
    false;

void toast(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Contenedor de página con ancho máximo y márgenes como la web.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1200, this.padding});
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 32.0;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(padding: padding ?? EdgeInsets.fromLTRB(gutter, 16, gutter, 96), children: children),
        ),
      ),
    );
  }
}

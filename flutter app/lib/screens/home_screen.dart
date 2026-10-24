import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repo.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Lo que hay que resolver hoy: quién llega, quién se va, qué falta cobrar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final t = today();
    final ts = ymd(t);
    final first = (session.profile?.name ?? '').split(' ').first;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/reservas/nueva'),
        backgroundColor: MM.ink,
        foregroundColor: MM.cream,
        icon: const Icon(Icons.add),
        label: const Text('Nueva reserva'),
      ),
      body: SettingsBuilder(
        builder: (context, settings) => StreamView<List<Reservation>>(
          stream: Repo.instance.upcoming(),
          builder: (context, all) {
            final active = all.where((r) => r.occupies && !r.isBlock).toList();
            final arrivals = active.where((r) => r.checkIn == ts).toList();
            final departures = active.where((r) => r.checkOut == ts).toList();
            final inHouse = active.where((r) => r.coversNight(ts)).toList();
            final occupiedCabins = {for (final r in inHouse) ...r.cabins};
            final week = ymd(t.add(const Duration(days: 8)));
            final soon = active.where((r) => r.checkIn.compareTo(ts) > 0 && r.checkIn.compareTo(week) < 0).toList();
            final in15 = ymd(t.add(const Duration(days: 15)));
            final toCollect = active
                .where((r) => r.status == ResStatus.confirmada && (r.balance ?? 0) > 0 && r.checkIn.compareTo(in15) < 0 && r.checkOut.compareTo(ts) >= 0)
                .toList();
            final inquiries = active.where((r) => r.status == ResStatus.consulta).toList();
            final review = active.where((r) => r.warnings.isNotEmpty).toList();
            final wide = MediaQuery.sizeOf(context).width >= 900;

            final cards = <Widget>[
              _ListCard(title: 'Llegan hoy', icon: Icons.login, empty: 'Nadie llega hoy.', items: arrivals, settings: settings, showBalance: true),
              _ListCard(title: 'Se van hoy', icon: Icons.logout, empty: 'Nadie se va hoy.', items: departures, settings: settings, cleaning: true),
              _ListCard(title: 'Próximos 7 días', icon: Icons.date_range, empty: 'Sin llegadas esta semana.', items: soon, settings: settings, showDate: true),
              _ListCard(
                title: 'Saldos a cobrar',
                icon: Icons.payments_outlined,
                empty: 'No hay saldos pendientes en los próximos 15 días.',
                items: toCollect,
                settings: settings,
                showBalance: true,
                showDate: true,
                footer: toCollect.isEmpty ? null : 'Total: ${fmtMoney(toCollect.fold<num>(0, (a, r) => a + (r.balance ?? 0)))}',
              ),
              if (inquiries.isNotEmpty)
                _ListCard(title: 'Consultas sin seña', icon: Icons.hourglass_empty, empty: '', items: inquiries, settings: settings, showDate: true),
              if (review.isNotEmpty)
                _ListCard(
                  title: 'Para revisar (importación)',
                  icon: Icons.error_outline,
                  empty: '',
                  items: review,
                  settings: settings,
                  showDate: true,
                  footer: 'Estas reservas vinieron de la planilla con datos que no cierran. Abrilas, corregí y tocá "Marcar revisada".',
                ),
              const _MaintenanceCard(),
            ];

            return PageBody(children: [
              SectionHead(sticker: fmtDay(t), title: first.isEmpty ? 'Hoy' : 'Hola, $first'),
              Wrap(spacing: 10, runSpacing: 10, children: [
                InfoChip('${occupiedCabins.length} de ${settings.cabins.length} cabañas ocupadas esta noche', icon: Icons.cottage_outlined, color: MM.sauce, fg: MM.forest),
                InfoChip('${inHouse.fold<int>(0, (a, r) => a + (r.people ?? 0))} huéspedes', icon: Icons.people_outline),
                InfoChip('${arrivals.length} llegadas · ${departures.length} salidas', icon: Icons.swap_horiz),
              ]),
              const SizedBox(height: 16),
              _TonightStrip(settings: settings, inHouse: inHouse),
              const SizedBox(height: 20),
              if (wide)
                LayoutBuilder(
                  builder: (context, box) => Wrap(spacing: 16, runSpacing: 16, children: [
                    for (final c in cards) SizedBox(width: (box.maxWidth - 16) / 2, child: c),
                  ]),
                )
              else
                ...[for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 14), child: c)],
            ]);
          },
        ),
      ),
    );
  }
}

/// Las seis cabañas con quién duerme hoy en cada una.
class _TonightStrip extends StatelessWidget {
  const _TonightStrip({required this.settings, required this.inHouse});
  final Settings settings;
  final List<Reservation> inHouse;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: settings.cabins.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final c = settings.cabins[i];
            final r = inHouse.where((r) => r.cabins.contains(c.id)).firstOrNull;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: r == null ? () => context.push('/reservas/nueva?cabin=${c.id}&in=${ymd(today())}') : () => context.push('/reservas/${r.id}'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 168,
                  child: Stack(fit: StackFit.expand, children: [
                    Image.asset('assets/img/cabana-${c.id}.webp', fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [MM.ink.withValues(alpha: .85), Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: MM.cream, shape: BoxShape.circle),
                        child: Text('${c.id}', style: MM.display(16)),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 8,
                      child: InfoChip(r == null ? 'Libre' : 'Ocupada', color: r == null ? MM.ocre : MM.sauce, fg: MM.ink),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Text(
                        r == null ? 'Tocá para reservar' : '${r.name}${r.people != null ? ' · ${r.people}p' : ''}\nhasta ${fmtShort(r.outDate)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: MM.cream, fontWeight: FontWeight.w700, height: 1.3),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      );
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.icon,
    required this.empty,
    required this.items,
    required this.settings,
    this.showBalance = false,
    this.showDate = false,
    this.cleaning = false,
    this.footer,
  });
  final String title, empty;
  final IconData icon;
  final List<Reservation> items;
  final Settings settings;
  final bool showBalance, showDate, cleaning;
  final String? footer;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: MM.rioDeep),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: MM.display(20))),
              if (items.isNotEmpty) InfoChip('${items.length}'),
              const SizedBox(width: 8),
            ]),
            const SizedBox(height: 6),
            if (items.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(empty, style: const TextStyle(color: MM.inkSoft)))
            else
              for (final r in items.take(8))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: StatusDot(r, size: 14),
                  title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    r.cabinsLabel,
                    if (showDate) '${fmtShort(r.inDate)} → ${fmtShort(r.outDate)}',
                    if (r.people != null) '${r.people}p',
                    if (cleaning) 'Preparar para la próxima llegada',
                    if (showBalance && (r.balance ?? 0) > 0) 'Saldo ${fmtMoney(r.balance)}',
                    if (r.breakfast) 'Desayuno',
                  ].join(' · ')),
                  trailing: IconButton(
                    tooltip: 'WhatsApp',
                    icon: const Icon(Icons.chat_outlined, color: MM.rioDeep),
                    onPressed: () => showWhatsAppPicker(context, r, settings),
                  ),
                  onTap: () => context.push('/reservas/${r.id}'),
                ),
            if (items.length > 8) Text('y ${items.length - 8} más', style: const TextStyle(color: MM.inkSoft)),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6, right: 8),
                child: Text(footer!, style: const TextStyle(fontWeight: FontWeight.w700, color: MM.forest)),
              ),
          ]),
        ),
      );
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard();

  @override
  Widget build(BuildContext context) => StreamView<List<MaintenanceItem>>(
        stream: Repo.instance.maintenance(),
        builder: (context, all) {
          final open = all.where((m) => m.status != MStatus.hecho).toList();
          return Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.handyman_outlined, color: MM.rioDeep),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Mantenimiento pendiente', style: MM.display(20))),
                  if (open.isNotEmpty) InfoChip('${open.length}'),
                  const SizedBox(width: 8),
                ]),
                const SizedBox(height: 6),
                if (open.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Todo en orden.', style: TextStyle(color: MM.inkSoft))),
                for (final m in open.take(6))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(m.status == MStatus.enCurso ? Icons.autorenew : Icons.radio_button_unchecked, color: MM.canyon),
                    title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${areaLabel(m.area)} · desde ${fmtShort(parseYmd(m.date))}'),
                    onTap: () => context.go('/mantenimiento'),
                  ),
              ]),
            ),
          );
        },
      );
}

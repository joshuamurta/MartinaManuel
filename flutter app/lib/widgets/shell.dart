import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../router.dart';
import '../theme.dart';

class _Dest {
  const _Dest(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const _dests = [
  _Dest('/', 'Hoy', Icons.wb_sunny_outlined),
  _Dest('/diagrama', 'Diagrama', Icons.calendar_view_month_outlined),
  _Dest('/reservas', 'Reservas', Icons.event_note_outlined),
  _Dest('/mantenimiento', 'Mantenimiento', Icons.handyman_outlined),
  _Dest('/caja', 'Caja', Icons.account_balance_wallet_outlined),
  _Dest('/numeros', 'Números', Icons.insights_outlined),
  _Dest('/usuarios', 'Usuarios', Icons.group_outlined),
  _Dest('/ajustes', 'Ajustes', Icons.tune_outlined),
];

/// Navegación: barra inferior en el celular, riel lateral en pantallas anchas.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  int _indexOf(List<_Dest> dests) {
    final i = dests.lastIndexWhere((d) => d.path == '/' ? location == '/' : location.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final dests = _dests.where((d) => canOpen(session, d.path)).toList();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1200,
            selectedIndex: _indexOf(dests),
            onDestinationSelected: (i) => context.go(dests[i].path),
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 24),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const BrandMark(size: 40),
                if (MediaQuery.sizeOf(context).width >= 1200) ...[
                  const SizedBox(width: 10),
                  Text('Martina Manuel', style: MM.display(20)),
                ],
              ]),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(padding: const EdgeInsets.only(bottom: 16), child: _AccountButton()),
              ),
            ),
            destinations: [
              for (final d in dests) NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          Expanded(child: child),
        ]),
      );
    }

    // En el celular entran cuatro destinos y "Más" agrupa el resto.
    const main = 4;
    final idx = _indexOf(dests);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx < main ? idx : main,
        onDestinationSelected: (i) {
          if (i < main) {
            context.go(dests[i].path);
          } else {
            _moreSheet(context, dests.sublist(main));
          }
        },
        destinations: [
          for (final d in dests.take(main)) NavigationDestination(icon: Icon(d.icon), label: d.label),
          const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Más'),
        ],
      ),
    );
  }

  void _moreSheet(BuildContext context, List<_Dest> rest) {
    final session = SessionScope.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: MM.soft,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final d in rest)
            ListTile(
              leading: Icon(d.icon),
              title: Text(d.label, style: MM.display(24)),
              onTap: () {
                Navigator.pop(sheet);
                context.go(d.path);
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(session.profile?.name ?? ''),
            subtitle: Text(session.profile?.email ?? ''),
            trailing: TextButton(onPressed: session.signOut, child: const Text('Salir')),
          ),
        ]),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final name = session.profile?.name ?? '';
    return PopupMenuButton<String>(
      tooltip: 'Cuenta',
      onSelected: (_) => session.signOut(),
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Text('$name\n${session.profile?.email ?? ''}')),
        const PopupMenuItem(value: 'out', child: Text('Cerrar sesión')),
      ],
      child: CircleAvatar(
        backgroundColor: MM.forest,
        child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: MM.display(18, color: MM.cream)),
      ),
    );
  }
}

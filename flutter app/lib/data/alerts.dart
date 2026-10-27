import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import 'repo.dart';
import 'session.dart';

class Alert {
  const Alert(this.id, this.text, this.icon, this.route, {this.urgent = false});
  final String id;
  final String text;
  final IconData icon;
  final String route;
  final bool urgent;
}

/// Avisos dentro de la app (sin notificaciones push): lo que cada uno tiene
/// que resolver hoy según sus permisos. La barra muestra cuántos hay y, con
/// la app abierta, cada aviso nuevo aparece en un cartel.
class Alerts extends ChangeNotifier {
  Alerts(this.session) {
    session.addListener(_restart);
    _restart();
  }

  final Session session;
  List<Alert> items = [];
  final _news = StreamController<Alert>.broadcast();
  Stream<Alert> get news => _news.stream;

  final _subs = <StreamSubscription<dynamic>>[];
  final _data = <String, dynamic>{};
  int _expected = 0;
  Set<String>? _seen; // null hasta que llegó todo la primera vez
  String _key = '';

  void _restart() {
    final p = session.perms;
    final uid = session.profile?.uid;
    final key = '$uid ${p.admin} ${p.levels}';
    if (key == _key) return;
    _key = key;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _data.clear();
    _seen = null;
    items = [];
    final repo = Repo.instance;
    final streams = <String, Stream<dynamic>>{
      if (session.canWork && p.can('mantenimiento')) 'maint': repo.maintenance(),
      if (session.canWork && p.can('limpieza')) ...{
        'events': repo.housekeeping(),
        'done': repo.cleaningDone(),
        'tasks': repo.cleaningTasks(),
      },
      if (session.canWork && p.can('compras')) 'purchases': repo.purchases(),
      if (session.canWork && p.canEdit('reservas')) 'res': repo.upcoming(),
    };
    _expected = streams.length;
    for (final e in streams.entries) {
      _subs.add(e.value.listen((v) {
        _data[e.key] = v;
        _recompute();
      }, onError: (_) {}));
    }
    notifyListeners();
  }

  void _recompute() {
    final uid = session.profile?.uid;
    final p = session.perms;
    final t = ymd(today());
    final tomorrow = ymd(today().add(const Duration(days: 1)));
    final list = <Alert>[];

    final maint = _data['maint'] as List<MaintenanceItem>?;
    if (maint != null) {
      // El staff ve sólo lo suyo; encargados y admins, todo lo vencido.
      final mine = !p.can('reservas');
      for (final m in maint.where((m) => m.dueBy(t) && (!mine || m.isFor(uid)))) {
        final late = m.dueDate!.compareTo(t) < 0;
        list.add(Alert('m:${m.id}:${m.dueDate}', '${late ? 'Atrasada' : 'Para hoy'}: ${m.title} (${areaLabel(m.area)})', Icons.handyman_outlined,
            '/mantenimiento',
            urgent: late));
      }
    }

    final events = _data['events'] as List<CleaningEvent>?;
    final done = _data['done'] as Set<String>? ?? const {};
    if (events != null) {
      for (final e in events.where((e) => (e.date == t || (e.arrival && e.date == tomorrow)) && !done.contains(e.key))) {
        final when = e.date == t ? 'Hoy' : 'Mañana';
        final text = e.arrival
            ? '$when llegan a la Cabaña ${e.cabin}${e.people != null ? ' (${e.people})' : ''}: ${e.beds ?? 'armado a confirmar'}'
            : '$when se van de la Cabaña ${e.cabin}: limpiar';
        list.add(Alert('c:${e.key}', text, Icons.cleaning_services_outlined, '/limpieza', urgent: e.date == t));
      }
    }
    final tasks = _data['tasks'] as List<CleaningTask>?;
    for (final k in tasks ?? const <CleaningTask>[]) {
      if (k.done || k.date.compareTo(t) > 0) continue;
      list.add(Alert('k:${k.id}', 'Limpieza${k.cabin != null ? ' · Cabaña ${k.cabin}' : ''}: ${k.text}', Icons.checklist, '/limpieza'));
    }

    final purchases = _data['purchases'] as List<Purchase>?;
    for (final pu in purchases ?? const <Purchase>[]) {
      if (p.canEdit('compras') && pu.status == PStatus.pedido) {
        list.add(Alert('p:${pu.id}:pedido', 'Pedido${pu.requestedName != null ? ' de ${pu.requestedName}' : ''}: ${pu.item}', Icons.shopping_cart_outlined,
            '/compras'));
      } else if (!p.canEdit('compras') && pu.status == PStatus.comprado && pu.requestedBy == uid) {
        list.add(Alert('p:${pu.id}:comprado', 'Ya se compró: ${pu.item}', Icons.shopping_cart_checkout, '/compras'));
      }
    }

    final res = _data['res'] as List<Reservation>?;
    if (res != null) {
      // Que nadie llegue sin saber cómo tienen que estar armadas las camas.
      final limit = ymd(today().add(const Duration(days: 3)));
      for (final r in res.where((r) => r.occupies && !r.isBlock && r.checkIn.compareTo(t) >= 0 && r.checkIn.compareTo(limit) <= 0)) {
        final missing = [
          for (final c in r.cabins)
            if ((defaultCabins.where((x) => x.id == c).firstOrNull?.hasBedOptions ?? false) && !r.beds.containsKey(c)) c,
        ];
        if (missing.isEmpty) continue;
        list.add(Alert('b:${r.id}', 'Definir camas: ${r.name} · Cabaña ${missing.join(', ')} · llega ${fmtShort(r.inDate)}', Icons.bed_outlined,
            '/reservas/${r.id}',
            urgent: r.checkIn == t));
      }
    }

    list.sort((a, b) => (b.urgent ? 1 : 0) - (a.urgent ? 1 : 0));
    items = list;
    final ids = {for (final a in list) a.id};
    if (_seen == null) {
      if (_data.length >= _expected) _seen = ids;
    } else {
      for (final a in list.where((a) => !_seen!.contains(a.id))) {
        _news.add(a);
      }
      _seen!.addAll(ids);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    session.removeListener(_restart);
    for (final s in _subs) {
      s.cancel();
    }
    _news.close();
    super.dispose();
  }
}

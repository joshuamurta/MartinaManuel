import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

/// Acceso a Firestore. Colecciones:
///   reservations (+ reservationMoney con la plata), maintenance
///   (+ maintenanceCosts), movements, users, invites, settings/general,
///   public/availability (la lee la web), meta/setup, meta/migrations.
class Repo {
  Repo._();
  static final instance = Repo._();

  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Permisos de quien usa la app; los actualiza Session. Deciden si se leen
  /// y escriben los montos y los costos.
  Perms perms = Perms.none;

  CollectionReference<Map<String, dynamic>> get _res => _db.collection('reservations');
  CollectionReference<Map<String, dynamic>> get _money => _db.collection('reservationMoney');
  CollectionReference<Map<String, dynamic>> get _maint => _db.collection('maintenance');
  CollectionReference<Map<String, dynamic>> get _costs => _db.collection('maintenanceCosts');
  CollectionReference<Map<String, dynamic>> get _mov => _db.collection('movements');

  Stream<Map<String, Map<String, dynamic>>> _byId(CollectionReference<Map<String, dynamic>> c) =>
      c.snapshots().map((q) => {for (final d in q.docs) d.id: d.data()});

  Future<Map<String, Map<String, dynamic>>> _byIdOnce(CollectionReference<Map<String, dynamic>> c) async =>
      {for (final d in (await c.get()).docs) d.id: d.data()};

  // ---------- Ajustes ----------

  Stream<Settings> settings() => _db.doc('settings/general').snapshots().map((d) => Settings.fromMap(d.data()));

  Future<void> saveSettings(Settings s) => _db.doc('settings/general').set(s.toMap(), SetOptions(merge: true));

  // ---------- Reservas ----------

  /// Reservas que tocan el rango [from, to) (fechas 'yyyy-MM-dd').
  Stream<List<Reservation>> reservationsBetween(String from, String to) {
    final list = _res
        .where('checkOut', isGreaterThan: from)
        .orderBy('checkOut')
        .snapshots()
        .map((q) => [for (final d in q.docs) Reservation.fromDoc(d)].where((r) => r.checkIn.compareTo(to) < 0).toList()
          ..sort((a, b) => a.checkIn.compareTo(b.checkIn)));
    if (!perms.readsMoney) return list;
    return _combine(list, _byId(_money), (rs, money) => [for (final r in rs) r.withMoney(money[r.id])]);
  }

  Stream<List<Reservation>> upcoming() => reservationsBetween(ymd(today().subtract(const Duration(days: 1))), '9999-12-31');

  Future<List<Reservation>> all() async {
    final q = await _res.orderBy('checkIn', descending: true).get();
    final money = perms.readsMoney ? await _byIdOnce(_money) : const <String, Map<String, dynamic>>{};
    return [for (final d in q.docs) Reservation.fromDoc(d).withMoney(money[d.id])];
  }

  Stream<Reservation?> reservation(String id) {
    final doc = _res.doc(id).snapshots().map((d) => d.exists ? Reservation.fromDoc(d) : null);
    if (!perms.readsMoney) return doc;
    return _combine(doc, _money.doc(id).snapshots(), (r, m) => r?.withMoney(m.data()));
  }

  /// Reservas activas que se pisan con [r] en alguna cabaña.
  Future<List<Reservation>> conflictsFor(Reservation r) async {
    final q = await _res.where('checkOut', isGreaterThan: r.checkIn).get();
    return [for (final d in q.docs) Reservation.fromDoc(d)].where(r.overlaps).toList();
  }

  /// Guarda la reserva y, si tiene permiso de cobrar, sus montos y pagos. Cada
  /// pago nuevo con cuenta también queda como ingreso en la caja (mismo id),
  /// así la caja no se carga dos veces.
  Future<String> saveReservation(Reservation r, {List<Payment> removedPayments = const []}) async {
    final ref = r.id == null ? _res.doc() : _res.doc(r.id);
    r.id = ref.id;
    final batch = _db.batch();
    final data = r.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
    data['updatedBy'] = _uid;
    if (r.reservedAt == null) data['reservedAt'] = ymd(today());
    batch.set(ref, data);
    if (perms.editMoney) _setMoney(batch, r, removedPayments);
    await batch.commit();
    await publishAvailability();
    return ref.id;
  }

  void _setMoney(WriteBatch batch, Reservation r, List<Payment> removedPayments) {
    batch.set(_money.doc(r.id), r.moneyMap());
    for (final p in r.payments) {
      if (p.imported || p.account == null) continue;
      batch.set(_mov.doc(p.id), {
        'date': p.date,
        'detail': 'Reserva ${r.name} · ${r.cabinsLabel}${p.note == null || p.note!.isEmpty ? '' : ' · ${p.note}'}',
        'amount': p.amount,
        'account': p.account,
        'category': 'Reservas',
        'reservationId': r.id,
        'createdBy': _uid,
      });
    }
    for (final p in removedPayments) {
      if (!p.imported) batch.delete(_mov.doc(p.id));
    }
  }

  /// Para eliminar hace falta permiso de eliminar y de cobrar: se borran
  /// también los montos y los cobros que entraron a la caja.
  Future<void> deleteReservation(Reservation r) async {
    final batch = _db.batch()
      ..delete(_res.doc(r.id))
      ..delete(_money.doc(r.id));
    for (final p in r.payments) {
      if (!p.imported) batch.delete(_mov.doc(p.id));
    }
    await batch.commit();
    await publishAvailability();
  }

  String newPaymentId() => _mov.doc().id;

  /// Publica en public/availability qué noches está ocupada cada cabaña de
  /// hoy en adelante, sin nombres ni datos de los huéspedes. La web lo lee
  /// para pintar el calendario.
  Future<void> publishAvailability() async {
    final from = ymd(today());
    final q = await _res.where('checkOut', isGreaterThan: from).get();
    final ranges = <int, List<List<String>>>{for (final c in defaultCabins) c.id: []};
    final list = [for (final d in q.docs) Reservation.fromDoc(d)].where((r) => r.occupies).toList()
      ..sort((a, b) => a.checkIn.compareTo(b.checkIn));
    for (final r in list) {
      final start = r.checkIn.compareTo(from) < 0 ? from : r.checkIn;
      for (final c in r.cabins) {
        final l = ranges.putIfAbsent(c, () => []);
        // Une estadías pegadas o superpuestas para que el JSON quede chico.
        if (l.isNotEmpty && l.last[1].compareTo(start) >= 0) {
          if (r.checkOut.compareTo(l.last[1]) > 0) l.last[1] = r.checkOut;
        } else {
          l.add([start, r.checkOut]);
        }
      }
    }
    await _db.doc('public/availability').set({
      // Rangos [llegada, salida): la noche de salida queda libre.
      'json': jsonEncode({'from': from, 'cabins': ranges.map((k, v) => MapEntry('$k', v))}),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Importa el JSON de tools/importar_excel.py. Devuelve cuántas se escribieron.
  Future<int> importReservations(List<Reservation> list, {required bool overwrite, void Function(int done)? onProgress}) async {
    final existing = overwrite ? <String>{} : {for (final d in (await _res.get()).docs) d.id};
    final todo = list.where((r) => !existing.contains(r.id)).toList();
    var done = 0;
    for (var i = 0; i < todo.length; i += 400) {
      final batch = _db.batch();
      for (final r in todo.skip(i).take(400)) {
        batch
          ..set(_res.doc(r.id), r.toMap()..['importedAt'] = FieldValue.serverTimestamp())
          ..set(_money.doc(r.id), r.moneyMap());
      }
      await batch.commit();
      done += todo.skip(i).take(400).length;
      onProgress?.call(done);
    }
    await publishAvailability();
    return done;
  }

  // ---------- Mantenimiento ----------

  Stream<List<MaintenanceItem>> maintenance() {
    final list = _maint.orderBy('date', descending: true).snapshots().map((q) => [for (final d in q.docs) MaintenanceItem.fromDoc(d)]);
    if (!perms.costs) return list;
    return _combine(list, _byId(_costs), (items, costs) => [
          for (final m in items) m..cost = costs.containsKey(m.id) ? costs[m.id]!['cost'] : m.cost,
        ]);
  }

  /// Guarda el arreglo; el costo sólo si tiene permiso para editarlo.
  Future<void> saveMaintenance(MaintenanceItem m) {
    m.createdBy ??= _uid;
    final ref = m.id == null ? _maint.doc() : _maint.doc(m.id);
    m.id = ref.id;
    final batch = _db.batch()..set(ref, m.toMap()..['updatedAt'] = FieldValue.serverTimestamp());
    if (perms.editCosts) batch.set(_costs.doc(ref.id), {'cost': m.cost});
    return batch.commit();
  }

  Future<void> deleteMaintenance(String id) => (_db.batch()
        ..delete(_maint.doc(id))
        ..delete(_costs.doc(id)))
      .commit();

  // ---------- Caja ----------

  Stream<List<Movement>> movements() =>
      _mov.orderBy('date', descending: true).snapshots().map((q) => [for (final d in q.docs) Movement.fromDoc(d)]);

  Future<void> saveMovement(Movement m) {
    m.createdBy ??= _uid;
    return m.id == null ? _mov.add(m.toMap()) : _mov.doc(m.id).set(m.toMap());
  }

  Future<void> deleteMovement(String id) => _mov.doc(id).delete();

  // ---------- Usuarios ----------

  Stream<List<AppUser>> users() =>
      _db.collection('users').snapshots().map((q) => [for (final d in q.docs) AppUser.fromDoc(d)]..sort((a, b) => a.name.compareTo(b.name)));

  Stream<List<Map<String, dynamic>>> invites() =>
      _db.collection('invites').snapshots().map((q) => [for (final d in q.docs) {...d.data(), 'email': d.id}]);

  Future<void> invite(String email, String name, Role role, {Map<String, int>? perms}) => _db
      .doc('invites/${email.trim().toLowerCase()}')
      .set({'name': name, 'role': role.name, 'perms': ?perms, 'by': _uid, 'at': FieldValue.serverTimestamp()});

  Future<void> deleteInvite(String email) => _db.doc('invites/$email').delete();

  Future<void> createUserProfile(String uid, String email, String name, Role role, {Map<String, int>? perms}) => _db.doc('users/$uid').set({
        'email': email.trim().toLowerCase(),
        'name': name,
        'role': role.name,
        'perms': ?perms,
        'active': true,
        'provider': 'password',
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// [perms] null deja los permisos como están; [resetPerms] vuelve a los del rol.
  Future<void> updateUser(String uid, {String? name, Role? role, bool? active, Map<String, int>? perms, bool resetPerms = false}) =>
      _db.doc('users/$uid').update({
        'name': ?name,
        'role': ?role?.name,
        'active': ?active,
        'perms': ?(resetPerms ? FieldValue.delete() : perms),
      });

  // ---------- Migración ----------

  Stream<bool> moneySplitDone() => _db.doc('meta/migrations').snapshots().map((d) => d.data()?['moneySplit'] == true);

  /// Pasa los montos de cada reserva a reservationMoney y los costos de
  /// mantenimiento a maintenanceCosts, para que se puedan ocultar. También
  /// convierte el rol viejo 'user' en 'encargado'. Se puede repetir sin
  /// perder nada. Devuelve cuántos documentos movió.
  Future<int> splitMoney() async {
    var moved = 0;
    final ops = <void Function(WriteBatch)>[];
    for (final d in (await _res.get()).docs) {
      final m = d.data();
      final notes = m['notes'] as String?;
      // La importación dejaba la aclaración de la tarifa al final de las notas.
      final i = notes?.indexOf('Tarifa: ') ?? -1;
      final hasTarifa = i == 0 || (i > 0 && notes!.substring(0, i).endsWith(' · '));
      if (!Reservation.moneyKeys.any(m.containsKey) && !hasTarifa) continue;
      final money = {for (final k in Reservation.moneyKeys) if (m.containsKey(k)) k: m[k]};
      final update = <String, dynamic>{for (final k in Reservation.moneyKeys) if (m.containsKey(k)) k: FieldValue.delete()};
      if (hasTarifa) {
        money['priceNote'] = notes!.substring(i + 8);
        final rest = notes.substring(0, i).replaceFirst(RegExp(r' · $'), '');
        update['notes'] = rest.isEmpty ? null : rest;
      }
      ops.add((b) => b
        ..set(_money.doc(d.id), money, SetOptions(merge: true))
        ..update(d.reference, update));
    }
    for (final d in (await _maint.get()).docs) {
      if (!d.data().containsKey('cost')) continue;
      final cost = d.data()['cost'];
      ops.add((b) => b
        ..set(_costs.doc(d.id), {'cost': cost})
        ..update(d.reference, {'cost': FieldValue.delete()}));
    }
    for (final d in (await _db.collection('users').where('role', isEqualTo: 'user').get()).docs) {
      ops.add((b) => b.update(d.reference, {'role': Role.encargado.name}));
    }
    // Cada operación son hasta dos escrituras: 200 por lote quedan bajo el límite de 500.
    for (var i = 0; i < ops.length; i += 200) {
      final batch = _db.batch();
      for (final op in ops.skip(i).take(200)) {
        op(batch);
      }
      await batch.commit();
      moved += ops.skip(i).take(200).length;
    }
    await _db.doc('meta/migrations').set({'moneySplit': true, 'at': FieldValue.serverTimestamp(), 'by': _uid}, SetOptions(merge: true));
    return moved;
  }

  Future<void> deleteUserProfile(String uid) => _db.doc('users/$uid').delete();
}

class Settings {
  Settings({required this.cabins, required this.holidays, this.paymentInfo, this.checkInTime, this.checkOutTime, this.breakfastPrice});

  final List<Cabin> cabins;
  final Map<String, String> holidays;
  final String? paymentInfo; // alias/CBU para los mensajes de WhatsApp
  final String? checkInTime;
  final String? checkOutTime;
  final num? breakfastPrice;

  Cabin cabin(int id) => cabins.firstWhere((c) => c.id == id, orElse: () => defaultCabins.firstWhere((c) => c.id == id));

  factory Settings.fromMap(Map<String, dynamic>? m) {
    m ??= {};
    final saved = [for (final c in (m['cabins'] as List? ?? const [])) Cabin.fromMap(Map<String, dynamic>.from(c))];
    return Settings(
      cabins: saved.isEmpty ? defaultCabins : saved,
      holidays: {...baseHolidays, ...Map<String, String>.from(m['holidays'] ?? const {})},
      paymentInfo: m['paymentInfo'],
      checkInTime: m['checkInTime'] ?? '14:00',
      checkOutTime: m['checkOutTime'] ?? '10:00',
      breakfastPrice: m['breakfastPrice'],
    );
  }

  Map<String, dynamic> toMap() => {
        'cabins': [for (final c in cabins) c.toMap()],
        'holidays': {
          for (final e in holidays.entries)
            if (baseHolidays[e.key] != e.value) e.key: e.value,
        },
        'paymentInfo': paymentInfo,
        'checkInTime': checkInTime,
        'checkOutTime': checkOutTime,
        'breakfastPrice': breakfastPrice,
      };
}

/// Combina el último valor de dos streams (como combineLatest).
Stream<T> _combine<A, B, T>(Stream<A> a, Stream<B> b, T Function(A a, B b) f) {
  late StreamController<T> c;
  StreamSubscription<A>? sa;
  StreamSubscription<B>? sb;
  A? lastA;
  B? lastB;
  var hasA = false, hasB = false;
  void emit() {
    if (hasA && hasB) c.add(f(lastA as A, lastB as B));
  }

  c = StreamController<T>(
    onListen: () {
      sa = a.listen((v) {
        lastA = v;
        hasA = true;
        emit();
      }, onError: c.addError);
      sb = b.listen((v) {
        lastB = v;
        hasB = true;
        emit();
      }, onError: c.addError);
    },
    onCancel: () async {
      await sa?.cancel();
      await sb?.cancel();
    },
  );
  return c.stream;
}

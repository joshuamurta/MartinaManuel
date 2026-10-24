import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

/// Acceso a Firestore. Colecciones:
///   reservations, maintenance, movements, users, invites,
///   settings/general, public/availability (la lee la web), meta/setup.
class Repo {
  Repo._();
  static final instance = Repo._();

  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _res => _db.collection('reservations');
  CollectionReference<Map<String, dynamic>> get _maint => _db.collection('maintenance');
  CollectionReference<Map<String, dynamic>> get _mov => _db.collection('movements');

  // ---------- Ajustes ----------

  Stream<Settings> settings() => _db.doc('settings/general').snapshots().map((d) => Settings.fromMap(d.data()));

  Future<void> saveSettings(Settings s) => _db.doc('settings/general').set(s.toMap(), SetOptions(merge: true));

  // ---------- Reservas ----------

  /// Reservas que tocan el rango [from, to) (fechas 'yyyy-MM-dd').
  Stream<List<Reservation>> reservationsBetween(String from, String to) => _res
      .where('checkOut', isGreaterThan: from)
      .orderBy('checkOut')
      .snapshots()
      .map((q) => [for (final d in q.docs) Reservation.fromDoc(d)].where((r) => r.checkIn.compareTo(to) < 0).toList()
        ..sort((a, b) => a.checkIn.compareTo(b.checkIn)));

  Stream<List<Reservation>> upcoming() => reservationsBetween(ymd(today().subtract(const Duration(days: 1))), '9999-12-31');

  Future<List<Reservation>> all() async {
    final q = await _res.orderBy('checkIn', descending: true).get();
    return [for (final d in q.docs) Reservation.fromDoc(d)];
  }

  Stream<Reservation?> reservation(String id) => _res.doc(id).snapshots().map((d) => d.exists ? Reservation.fromDoc(d) : null);

  /// Reservas activas que se pisan con [r] en alguna cabaña.
  Future<List<Reservation>> conflictsFor(Reservation r) async {
    final q = await _res.where('checkOut', isGreaterThan: r.checkIn).get();
    return [for (final d in q.docs) Reservation.fromDoc(d)].where(r.overlaps).toList();
  }

  /// Guarda la reserva y sus pagos. Cada pago nuevo con cuenta también queda
  /// como ingreso en la caja (mismo id), así la caja no se carga dos veces.
  Future<String> saveReservation(Reservation r, {List<Payment> removedPayments = const []}) async {
    final ref = r.id == null ? _res.doc() : _res.doc(r.id);
    r.id = ref.id;
    final batch = _db.batch();
    final data = r.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
    data['updatedBy'] = _uid;
    if (r.reservedAt == null) data['reservedAt'] = ymd(today());
    batch.set(ref, data);
    for (final p in r.payments) {
      if (p.imported || p.account == null) continue;
      batch.set(_mov.doc(p.id), {
        'date': p.date,
        'detail': 'Reserva ${r.name} · ${r.cabinsLabel}${p.note == null || p.note!.isEmpty ? '' : ' · ${p.note}'}',
        'amount': p.amount,
        'account': p.account,
        'category': 'Reservas',
        'reservationId': ref.id,
        'createdBy': _uid,
      });
    }
    for (final p in removedPayments) {
      if (!p.imported) batch.delete(_mov.doc(p.id));
    }
    await batch.commit();
    await publishAvailability();
    return ref.id;
  }

  Future<void> deleteReservation(Reservation r) async {
    final batch = _db.batch()..delete(_res.doc(r.id));
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
        batch.set(_res.doc(r.id), r.toMap()..['importedAt'] = FieldValue.serverTimestamp());
      }
      await batch.commit();
      done += todo.skip(i).take(400).length;
      onProgress?.call(done);
    }
    await publishAvailability();
    return done;
  }

  // ---------- Mantenimiento ----------

  Stream<List<MaintenanceItem>> maintenance() =>
      _maint.orderBy('date', descending: true).snapshots().map((q) => [for (final d in q.docs) MaintenanceItem.fromDoc(d)]);

  Future<void> saveMaintenance(MaintenanceItem m) {
    m.createdBy ??= _uid;
    final data = m.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
    return m.id == null ? _maint.add(data) : _maint.doc(m.id).set(data);
  }

  Future<void> deleteMaintenance(String id) => _maint.doc(id).delete();

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

  Future<void> invite(String email, String name, Role role) =>
      _db.doc('invites/${email.trim().toLowerCase()}').set({'name': name, 'role': role.name, 'by': _uid, 'at': FieldValue.serverTimestamp()});

  Future<void> deleteInvite(String email) => _db.doc('invites/$email').delete();

  Future<void> createUserProfile(String uid, String email, String name, Role role) => _db.doc('users/$uid').set({
        'email': email.trim().toLowerCase(),
        'name': name,
        'role': role.name,
        'active': true,
        'provider': 'password',
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateUser(String uid, {String? name, Role? role, bool? active}) => _db.doc('users/$uid').update({
        'name': ?name,
        'role': ?role?.name,
        'active': ?active,
      });

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

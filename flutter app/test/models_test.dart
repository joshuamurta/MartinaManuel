import 'package:flutter_test/flutter_test.dart';
import 'package:martina_manuel/models.dart';

void main() {
  test('armado de camas según lo que contó Claudio', () {
    String label(int id, int joined) => defaultCabins.firstWhere((c) => c.id == id).bedsLabel(joined);
    expect(label(1, 0), '2 simples');
    expect(label(1, 1), '1 matrimonial');
    expect(label(2, 0), '1 matrimonial + 2 simples');
    expect(label(3, 1), '1 matrimonial + 3 simples');
    expect(label(5, 2), '2 matrimoniales + 3 simples');
    expect(label(6, 2), '2 matrimoniales + 2 simples');
    expect(defaultCabins.firstWhere((c) => c.id == 2).hasBedOptions, isFalse);
  });

  test('las camas no se pierden al leer cabañas guardadas en Ajustes', () {
    final c = Cabin.fromMap({'id': 5, 'name': 'Cabaña 5', 'price': 100}).copyWith(price: 200);
    expect(c.joinable, 2);
    expect(c.singles, 7);
    expect(c.price, 200);
  });

  test('el armado viaja con la reserva y los montos no', () {
    final r = Reservation(name: 'X', cabins: [5], checkIn: '2026-11-01', checkOut: '2026-11-03', total: 10, beds: {5: 1}, cleaningNote: 'leña');
    final m = r.toMap();
    expect(m['beds'], {'5': 1});
    expect(m.containsKey('total'), isFalse);
    final back = Reservation.fromMap(m);
    expect(back.beds, {5: 1});
    expect(back.cleaningNote, 'leña');
  });

  test('evento de limpieza ida y vuelta', () {
    final e = CleaningEvent(date: '2026-11-01', cabin: 3, arrival: true, people: 4, beds: '1 matrimonial + 3 simples', crib: true);
    final back = CleaningEvent.fromMap(e.toMap());
    expect(back.key, '2026-11-01_3_in');
    expect(back.beds, e.beds);
    expect(back.crib, isTrue);
    expect(back.pets, isFalse);
  });

  test('permisos por defecto', () {
    final staff = Perms(defaultPerms(Role.staff));
    expect(staff.canEdit('mantenimiento'), isTrue);
    expect(staff.can('compras'), isTrue);
    expect(staff.canEdit('compras'), isFalse);
    expect(staff.costs, isFalse);
    final enc = Perms(defaultPerms(Role.encargado));
    expect(enc.canEdit('limpieza'), isTrue);
    expect(enc.money, isFalse);
    expect(roleFrom('user'), Role.encargado);
  });

  test('tarea vencida y asignada', () {
    final m = MaintenanceItem(area: 'pileta', title: 'Cloro', date: '2026-10-01', dueDate: '2026-10-27', assignedTo: 'a');
    expect(m.dueBy('2026-10-27'), isTrue);
    expect(m.dueBy('2026-10-26'), isFalse);
    expect(m.isFor('a'), isTrue);
    expect(m.isFor('b'), isFalse);
  });
}

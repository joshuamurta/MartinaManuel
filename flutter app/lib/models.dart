import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ---------- Fechas ----------
// Las fechas de estadía se guardan como texto 'yyyy-MM-dd': no dependen de la
// zona horaria y se ordenan y filtran bien en Firestore.

String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime parseYmd(String s) => DateTime(int.parse(s.substring(0, 4)), int.parse(s.substring(5, 7)), int.parse(s.substring(8, 10)));
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime today() => dateOnly(DateTime.now());
int nightsBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

final _dayFmt = DateFormat("EEE d 'de' MMM", 'es_AR');
final _shortFmt = DateFormat('d/M', 'es_AR');
final _monthFmt = DateFormat('MMMM yyyy', 'es_AR');
final _money = NumberFormat.decimalPattern('es_AR');

String fmtDay(DateTime d) => _dayFmt.format(d);
String fmtShort(DateTime d) => _shortFmt.format(d);
String fmtMonth(DateTime d) {
  final s = _monthFmt.format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String fmtMoney(num? v) => v == null ? '—' : '${v < 0 ? '-' : ''}\$ ${_money.format(v.abs().round())}';

// ---------- Usuarios ----------

enum Role { admin, user, pending }

Role roleFrom(String? s) => Role.values.firstWhere((r) => r.name == s, orElse: () => Role.pending);

String roleLabel(Role r) => switch (r) {
      Role.admin => 'Administrador',
      Role.user => 'Usuario',
      Role.pending => 'Pendiente de aprobación',
    };

class AppUser {
  AppUser({required this.uid, required this.email, required this.name, required this.role, required this.active, this.provider});
  final String uid;
  final String email;
  final String name;
  final Role role;
  final bool active;
  final String? provider;

  bool get isAdmin => role == Role.admin && active;
  bool get canWork => (role == Role.admin || role == Role.user) && active;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppUser(
      uid: d.id,
      email: m['email'] ?? '',
      name: m['name'] ?? '',
      role: roleFrom(m['role']),
      active: m['active'] ?? true,
      provider: m['provider'],
    );
  }
}

// ---------- Cabañas ----------

class Cabin {
  const Cabin({required this.id, required this.name, required this.capacity, required this.maxPeople, required this.size, this.price});
  final int id;
  final String name;
  final String capacity;
  final int maxPeople;
  final int size;
  final num? price; // tarifa por noche vigente

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'capacity': capacity, 'maxPeople': maxPeople, 'size': size, 'price': price};
  factory Cabin.fromMap(Map<String, dynamic> m) => Cabin(
        id: m['id'],
        name: m['name'],
        capacity: m['capacity'] ?? '',
        maxPeople: m['maxPeople'] ?? 2,
        size: m['size'] ?? 0,
        price: m['price'],
      );

  Cabin copyWith({num? price}) => Cabin(id: id, name: name, capacity: capacity, maxPeople: maxPeople, size: size, price: price ?? this.price);
}

/// Las mismas seis cabañas de web/js/data.js; las tarifas se cargan en Ajustes.
const defaultCabins = [
  Cabin(id: 1, name: 'Cabaña 1', capacity: '2 adultos + niño', maxPeople: 3, size: 35),
  Cabin(id: 2, name: 'Cabaña 2', capacity: '3 a 4 personas', maxPeople: 4, size: 52),
  Cabin(id: 3, name: 'Cabaña 3', capacity: 'hasta 5 personas', maxPeople: 5, size: 48),
  Cabin(id: 4, name: 'Cabaña 4', capacity: 'hasta 5 personas', maxPeople: 5, size: 48),
  Cabin(id: 5, name: 'Cabaña 5', capacity: '6 a 7 personas', maxPeople: 7, size: 78),
  Cabin(id: 6, name: 'Cabaña 6', capacity: 'hasta 6 personas', maxPeople: 6, size: 65),
];

// ---------- Reservas ----------

enum ResStatus { consulta, confirmada, cancelada, bloqueo }

String statusLabel(ResStatus s) => switch (s) {
      ResStatus.consulta => 'Consulta / sin seña',
      ResStatus.confirmada => 'Confirmada',
      ResStatus.cancelada => 'Cancelada',
      ResStatus.bloqueo => 'Bloqueo (no disponible)',
    };

const channels = {
  'whatsapp': 'WhatsApp',
  'web': 'Web',
  'instagram': 'Instagram',
  'facebook': 'Facebook',
  'google': 'Google Maps',
  'airbnb': 'Airbnb',
  'booking': 'Booking',
  'recomendado': 'Recomendado',
  'cliente': 'Cliente que vuelve',
  'canje': 'Canje / proveedor',
  'otro': 'Otro',
};

class Payment {
  Payment({required this.id, required this.date, required this.amount, this.account, this.note, this.imported = false});
  final String id; // mismo id que el movimiento de caja asociado
  final String date;
  final num amount;
  final String? account;
  final String? note;
  final bool imported;

  Map<String, dynamic> toMap() => {'id': id, 'date': date, 'amount': amount, 'account': account, 'note': note, 'imported': imported};
  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        id: m['id'] ?? '',
        date: m['date'] ?? '',
        amount: m['amount'] ?? 0,
        account: m['account'],
        note: m['note'],
        imported: m['imported'] ?? false,
      );
}

class Reservation {
  Reservation({
    this.id,
    required this.name,
    required this.cabins,
    required this.checkIn,
    required this.checkOut,
    this.status = ResStatus.confirmada,
    this.people,
    this.contact,
    this.email,
    this.channel,
    this.total,
    this.nightlyPrice,
    this.balanceUsd,
    this.payments = const [],
    this.breakfast = false,
    this.pets = false,
    this.crib = false,
    this.invoiceNo,
    this.invoiceDate,
    this.notes,
    this.reservedAt,
    this.warnings = const [],
    this.source,
    this.groupId,
  });

  String? id;
  String name;
  List<int> cabins;
  String checkIn; // primera noche
  String checkOut; // día de salida (no se duerme)
  ResStatus status;
  int? people;
  String? contact;
  String? email;
  String? channel;
  num? total;
  num? nightlyPrice;
  num? balanceUsd;
  List<Payment> payments;
  bool breakfast;
  bool pets;
  bool crib;
  String? invoiceNo;
  String? invoiceDate;
  String? notes;
  String? reservedAt;
  List<String> warnings; // avisos de la importación para revisar
  String? source;
  String? groupId;

  DateTime get inDate => parseYmd(checkIn);
  DateTime get outDate => parseYmd(checkOut);
  int get nights => nightsBetween(inDate, outDate);
  num get paid => payments.fold<num>(0, (a, p) => a + p.amount);
  num? get balance => total == null ? null : total! - paid;
  bool get occupies => status != ResStatus.cancelada;
  bool get isBlock => status == ResStatus.bloqueo;

  /// ¿Ocupa la cabaña la noche de [day]?
  bool coversNight(String day) => checkIn.compareTo(day) <= 0 && checkOut.compareTo(day) > 0;

  bool overlaps(Reservation o) =>
      o.occupies && occupies && o.id != id && o.cabins.any(cabins.contains) && o.checkIn.compareTo(checkOut) < 0 && o.checkOut.compareTo(checkIn) > 0;

  String get cabinsLabel => cabins.length == 1 ? 'Cabaña ${cabins.first}' : 'Cabañas ${cabins.join(', ')}';

  Map<String, dynamic> toMap() => {
        'name': name,
        'nameLower': name.toLowerCase(),
        'cabins': cabins,
        'checkIn': checkIn,
        'checkOut': checkOut,
        'status': status.name,
        'people': people,
        'contact': contact,
        'email': email,
        'channel': channel,
        'total': total,
        'nightlyPrice': nightlyPrice,
        'balanceUsd': balanceUsd,
        'payments': payments.map((p) => p.toMap()).toList(),
        'breakfast': breakfast,
        'pets': pets,
        'crib': crib,
        'invoiceNo': invoiceNo,
        'invoiceDate': invoiceDate,
        'notes': notes,
        'reservedAt': reservedAt,
        'warnings': warnings,
        'source': source,
        'groupId': groupId,
      };

  factory Reservation.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) => Reservation.fromMap(d.data() ?? {}, id: d.id);

  factory Reservation.fromMap(Map<String, dynamic> m, {String? id}) => Reservation(
        id: id ?? m['id'],
        name: m['name'] ?? '',
        cabins: List<int>.from(m['cabins'] ?? const []),
        checkIn: m['checkIn'],
        checkOut: m['checkOut'],
        status: ResStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => ResStatus.confirmada),
        people: (m['people'] as num?)?.toInt(),
        contact: m['contact'],
        email: m['email'],
        channel: m['channel'],
        total: m['total'],
        nightlyPrice: m['nightlyPrice'],
        balanceUsd: m['balanceUsd'],
        payments: [for (final p in (m['payments'] as List? ?? const [])) Payment.fromMap(Map<String, dynamic>.from(p))],
        breakfast: m['breakfast'] ?? false,
        pets: m['pets'] ?? false,
        crib: m['crib'] ?? false,
        invoiceNo: m['invoiceNo'],
        invoiceDate: m['invoiceDate'],
        notes: m['notes'],
        reservedAt: m['reservedAt'],
        warnings: List<String>.from(m['warnings'] ?? const []),
        source: m['source'],
        groupId: m['groupId'],
      );

  /// Fila del JSON generado por tools/importar_excel.py.
  factory Reservation.fromImport(Map<String, dynamic> m) {
    final total = m['total'] as num?;
    final balance = m['balance'] as num?;
    final deposit = m['deposit'] as num?;
    // La planilla tiene total, seña y saldo: lo cobrado es total − saldo.
    final paid = total != null && balance != null ? total - balance : deposit;
    final r = Reservation.fromMap(m, id: m['id']);
    r.status = ResStatus.confirmada;
    r.payments = [
      if (paid != null && paid > 0)
        Payment(id: '${m['id']}-p0', date: m['reservedAt'] ?? m['checkIn'], amount: paid, note: 'Cobrado según la planilla', imported: true),
    ];
    if (m['diagramLabel'] != null) r.notes = [r.notes, 'Diagrama: ${m['diagramLabel']}'].whereType<String>().join(' · ');
    if (m['priceNote'] != null) r.notes = [r.notes, 'Tarifa: ${m['priceNote']}'].whereType<String>().join(' · ');
    return r;
  }
}

// ---------- Mantenimiento ----------

/// Lugares del complejo con historial de arreglos, además de cada cabaña.
const maintenanceAreas = {
  'pileta': 'Piscina exterior',
  'climatizada': 'Piscina climatizada',
  'jacuzzi': 'Jacuzzi (cabaña 6)',
  'parque': 'Parque y riego',
  'fogon': 'Fogón y horno de barro',
  'rio': 'Bajada al río',
  'recepcion': 'Recepción',
  'general': 'General / instalaciones',
};

String areaLabel(String key) => key.startsWith('cabin-') ? 'Cabaña ${key.substring(6)}' : (maintenanceAreas[key] ?? key);

enum MStatus { pendiente, enCurso, hecho }

String mStatusLabel(MStatus s) => switch (s) {
      MStatus.pendiente => 'Pendiente',
      MStatus.enCurso => 'En curso',
      MStatus.hecho => 'Hecho',
    };

class MaintenanceItem {
  MaintenanceItem({
    this.id,
    required this.area,
    required this.title,
    required this.date,
    this.description,
    this.cost,
    this.provider,
    this.status = MStatus.pendiente,
    this.kind = 'reparacion',
    this.createdBy,
  });
  String? id;
  String area;
  String title;
  String date;
  String? description;
  num? cost;
  String? provider;
  MStatus status;
  String kind; // reparacion | preventivo | mejora
  String? createdBy;

  Map<String, dynamic> toMap() => {
        'area': area,
        'title': title,
        'date': date,
        'description': description,
        'cost': cost,
        'provider': provider,
        'status': status.name,
        'kind': kind,
        'createdBy': createdBy,
      };

  factory MaintenanceItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return MaintenanceItem(
      id: d.id,
      area: m['area'] ?? 'general',
      title: m['title'] ?? '',
      date: m['date'] ?? ymd(today()),
      description: m['description'],
      cost: m['cost'],
      provider: m['provider'],
      status: MStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => MStatus.pendiente),
      kind: m['kind'] ?? 'reparacion',
      createdBy: m['createdBy'],
    );
  }
}

// ---------- Caja ----------

/// Cuentas que hoy se llevan en hojas separadas de la planilla.
const accounts = {
  'caja': 'Caja (efectivo)',
  'frances': 'Banco Francés',
  'patagonia': 'Banco Patagonia',
  'mp_claudio': 'Mercado Pago Claudio',
  'mp_euge': 'Mercado Pago Euge',
  'usd': 'Dólares',
};

/// Rubros de la hoja GASTOS MENSUALES, agrupados.
const expenseCategories = [
  'Luz (Edemsa)',
  'Gas',
  'Internet / TV',
  'Celular',
  'Cloacas / municipales',
  'Impuestos (IIBB, autónomos)',
  'Seguros / emergencias',
  'Tarjetas',
  'Sueldos y personal',
  'Honorarios',
  'Artículos de limpieza',
  'Ropería / lavandería',
  'Ferretería',
  'Obra / mejoras',
  'Mantenimiento',
  'Combustible',
  'Gastos personales',
  'Créditos',
  'Otros',
];

const incomeCategories = ['Reservas', 'Desayunos', 'Otros ingresos'];

class Movement {
  Movement({
    this.id,
    required this.date,
    required this.detail,
    required this.amount,
    required this.account,
    required this.category,
    this.reservationId,
    this.createdBy,
  });
  String? id;
  String date;
  String detail;
  num amount; // positivo ingreso, negativo egreso
  String account;
  String category;
  String? reservationId;
  String? createdBy;

  bool get isIncome => amount >= 0;

  Map<String, dynamic> toMap() => {
        'date': date,
        'detail': detail,
        'amount': amount,
        'account': account,
        'category': category,
        'reservationId': reservationId,
        'createdBy': createdBy,
      };

  factory Movement.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Movement(
      id: d.id,
      date: m['date'] ?? '',
      detail: m['detail'] ?? '',
      amount: m['amount'] ?? 0,
      account: m['account'] ?? 'caja',
      category: m['category'] ?? 'Otros',
      reservationId: m['reservationId'],
      createdBy: m['createdBy'],
    );
  }
}

// ---------- Feriados ----------

/// Feriados nacionales de fecha fija + los móviles conocidos. En Ajustes se
/// agregan los puentes y traslados de cada año.
const baseHolidays = {
  '2026-01-01': 'Año Nuevo',
  '2026-02-16': 'Carnaval',
  '2026-02-17': 'Carnaval',
  '2026-03-24': 'Memoria, Verdad y Justicia',
  '2026-04-02': 'Malvinas',
  '2026-04-03': 'Viernes Santo',
  '2026-05-01': 'Día del Trabajador',
  '2026-05-25': 'Revolución de Mayo',
  '2026-06-20': 'Día de la Bandera',
  '2026-07-09': 'Independencia',
  '2026-12-08': 'Inmaculada Concepción',
  '2026-12-25': 'Navidad',
  '2027-01-01': 'Año Nuevo',
  '2027-02-08': 'Carnaval',
  '2027-02-09': 'Carnaval',
  '2027-03-24': 'Memoria, Verdad y Justicia',
  '2027-03-26': 'Viernes Santo',
  '2027-04-02': 'Malvinas',
  '2027-05-01': 'Día del Trabajador',
  '2027-05-25': 'Revolución de Mayo',
  '2027-06-20': 'Día de la Bandera',
  '2027-07-09': 'Independencia',
  '2027-12-08': 'Inmaculada Concepción',
  '2027-12-25': 'Navidad',
};

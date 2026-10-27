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

enum Role { admin, encargado, staff, pending }

/// 'user' es el rol que existía antes de los permisos: equivale a encargado.
Role roleFrom(String? s) => s == 'user' ? Role.encargado : Role.values.firstWhere((r) => r.name == s, orElse: () => Role.pending);

String roleLabel(Role r) => switch (r) {
      Role.admin => 'Administrador',
      Role.encargado => 'Encargado',
      Role.staff => 'Staff',
      Role.pending => 'Pendiente de aprobación',
    };

String roleHelp(Role r) => switch (r) {
      Role.admin => 'Ve y hace todo, incluidos usuarios y ajustes.',
      Role.encargado => 'Diagrama, reservas, mantenimiento, limpieza y compras, sin montos ni caja.',
      Role.staff => 'Sólo sus tareas (mantenimiento o limpieza) y pedir compras, sin costos.',
      Role.pending => 'Sin acceso.',
    };

/// Qué puede hacer cada usuario que no es administrador. Nivel 0 = no ve,
/// 1 = ve, 2 = edita. Se guarda en users/{uid}.perms y firestore.rules lo
/// hace cumplir con los mismos valores por defecto.
class PermDef {
  const PermDef(this.key, this.label, this.help, this.levels);
  final String key;
  final String label;
  final String help;
  final Map<int, String> levels;
}

const permDefs = [
  PermDef('reservas', 'Diagrama y reservas', 'Huéspedes, fechas y contacto', {0: 'No ve', 1: 'Ve', 2: 'Edita'}),
  PermDef('montos', 'Montos de reservas', 'Total, pagos, saldo y factura', {0: 'No ve', 1: 'Ve', 2: 'Cobra'}),
  PermDef('mantenimiento', 'Mantenimiento', 'Arreglos e historial', {0: 'No ve', 1: 'Ve', 2: 'Edita'}),
  PermDef('costos', 'Costos de mantenimiento', 'Cuánto salió cada arreglo', {0: 'No ve', 1: 'Ve', 2: 'Edita'}),
  PermDef('limpieza', 'Limpieza', 'Salidas, llegadas, armado de camas e indicaciones', {0: 'No ve', 1: 'Ve', 2: 'Edita'}),
  PermDef('compras', 'Compras', 'Pedidos de insumos y materiales', {0: 'No ve', 1: 'Pide', 2: 'Gestiona'}),
  PermDef('caja', 'Caja', 'Saldos, movimientos y gastos', {0: 'No ve', 1: 'Ve', 2: 'Edita'}),
  PermDef('numeros', 'Números', 'Ocupación y facturación', {0: 'No ve', 1: 'Ve'}),
  PermDef('eliminar', 'Eliminar', 'Borrar reservas y arreglos', {0: 'No', 2: 'Sí'}),
];

/// Permisos de cada rol mientras el admin no los cambie.
Map<String, int> defaultPerms(Role r) => switch (r) {
      Role.admin => {for (final d in permDefs) d.key: d.levels.keys.last},
      Role.encargado => {'reservas': 2, 'mantenimiento': 2, 'limpieza': 2, 'compras': 2},
      Role.staff => staffTemplates.values.first,
      Role.pending => {},
    };

/// Puntos de partida para el staff: el de mantenimiento o la mucama.
const staffTemplates = {
  'Mantenimiento': {'mantenimiento': 2, 'compras': 1},
  'Limpieza': {'limpieza': 2, 'compras': 1},
};

class Perms {
  const Perms(this.levels, {this.admin = false});
  static const none = Perms({});
  final Map<String, int> levels;
  final bool admin;

  int level(String key) => admin ? 2 : (levels[key] ?? 0);
  bool can(String key) => level(key) >= 1;
  bool canEdit(String key) => level(key) >= 2;

  bool get money => can('montos');
  bool get editMoney => canEdit('montos');
  bool get costs => can('costos');
  bool get editCosts => canEdit('costos');
  bool get delete => canEdit('eliminar');
  bool get readsMoney => money || can('numeros');
}

class AppUser {
  AppUser({required this.uid, required this.email, required this.name, required this.role, required this.active, this.provider, this.customPerms});
  final String uid;
  final String email;
  final String name;
  final Role role;
  final bool active;
  final String? provider;
  final Map<String, int>? customPerms; // null = los del rol

  bool get isAdmin => role == Role.admin && active;
  bool get canWork => role != Role.pending && active;
  Perms get perms => !active ? Perms.none : Perms(customPerms ?? defaultPerms(role), admin: isAdmin);

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppUser(
      uid: d.id,
      email: m['email'] ?? '',
      name: m['name'] ?? '',
      role: roleFrom(m['role']),
      active: m['active'] ?? true,
      provider: m['provider'],
      customPerms: m['perms'] == null ? null : {for (final e in (m['perms'] as Map).entries) '${e.key}': (e.value as num).toInt()},
    );
  }
}

// ---------- Cabañas ----------

class Cabin {
  const Cabin({
    required this.id,
    required this.name,
    required this.capacity,
    required this.maxPeople,
    required this.size,
    this.price,
    this.singles = 0,
    this.fixedDoubles = 0,
    this.joinable = 0,
  });
  final int id;
  final String name;
  final String capacity;
  final int maxPeople;
  final int size;
  final num? price; // tarifa por noche vigente
  final int singles; // camas de una plaza
  final int fixedDoubles; // matrimoniales que no se separan
  final int joinable; // cuántas matrimoniales se pueden armar juntando dos simples

  bool get hasBedOptions => joinable > 0;

  /// Camas con [joined] matrimoniales armadas: "1 matrimonial + 3 simples".
  String bedsLabel(int joined) {
    final doubles = fixedDoubles + joined;
    final single = singles - 2 * joined;
    return [
      if (doubles > 0) '$doubles ${doubles == 1 ? 'matrimonial' : 'matrimoniales'}',
      if (single > 0) '$single ${single == 1 ? 'simple' : 'simples'}',
    ].join(' + ');
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'capacity': capacity, 'maxPeople': maxPeople, 'size': size, 'price': price};

  /// Las camas no se editan en Ajustes: salen siempre de [defaultCabins].
  factory Cabin.fromMap(Map<String, dynamic> m) {
    final base = defaultCabins.where((c) => c.id == m['id']).firstOrNull;
    return Cabin(
      id: m['id'],
      name: m['name'],
      capacity: m['capacity'] ?? '',
      maxPeople: m['maxPeople'] ?? 2,
      size: m['size'] ?? 0,
      price: m['price'],
      singles: base?.singles ?? 0,
      fixedDoubles: base?.fixedDoubles ?? 0,
      joinable: base?.joinable ?? 0,
    );
  }

  Cabin copyWith({num? price}) => Cabin(
        id: id,
        name: name,
        capacity: capacity,
        maxPeople: maxPeople,
        size: size,
        price: price ?? this.price,
        singles: singles,
        fixedDoubles: fixedDoubles,
        joinable: joinable,
      );
}

/// Las mismas seis cabañas de web/js/data.js; las tarifas se cargan en Ajustes.
/// Camas según Claudio (audio del 27/10/2026).
const defaultCabins = [
  Cabin(id: 1, name: 'Cabaña 1', capacity: '2 adultos + niño', maxPeople: 3, size: 35, singles: 2, joinable: 1),
  Cabin(id: 2, name: 'Cabaña 2', capacity: '3 a 4 personas', maxPeople: 4, size: 52, singles: 2, fixedDoubles: 1),
  Cabin(id: 3, name: 'Cabaña 3', capacity: 'hasta 5 personas', maxPeople: 5, size: 48, singles: 5, joinable: 1),
  Cabin(id: 4, name: 'Cabaña 4', capacity: 'hasta 5 personas', maxPeople: 5, size: 48, singles: 5, joinable: 1),
  Cabin(id: 5, name: 'Cabaña 5', capacity: '6 a 7 personas', maxPeople: 7, size: 78, singles: 7, joinable: 2),
  Cabin(id: 6, name: 'Cabaña 6', capacity: 'hasta 6 personas', maxPeople: 6, size: 65, singles: 6, joinable: 2),
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
    this.priceNote,
    this.notes,
    this.reservedAt,
    this.warnings = const [],
    this.source,
    this.groupId,
    this.beds = const {},
    this.cleaningNote,
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
  String? priceNote; // aclaración de la tarifa (viene de la planilla)
  String? notes;
  String? reservedAt;
  List<String> warnings; // avisos de la importación para revisar
  String? source;
  String? groupId;
  Map<int, int> beds; // cabaña → matrimoniales armadas; sin dato = sin definir
  String? cleaningNote; // indicación para la mucama

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

  /// Campos de plata: viven en reservationMoney/{id}, que sólo leen quienes
  /// tienen permiso de montos (Firestore no puede ocultar campos sueltos).
  static const moneyKeys = ['total', 'nightlyPrice', 'balanceUsd', 'payments', 'invoiceNo', 'invoiceDate', 'priceNote'];

  Map<String, dynamic> moneyMap() => {
        'total': total,
        'nightlyPrice': nightlyPrice,
        'balanceUsd': balanceUsd,
        'payments': payments.map((p) => p.toMap()).toList(),
        'invoiceNo': invoiceNo,
        'invoiceDate': invoiceDate,
        'priceNote': priceNote,
      };

  Reservation withMoney(Map<String, dynamic>? m) {
    if (m == null) return this;
    total = m['total'];
    nightlyPrice = m['nightlyPrice'];
    balanceUsd = m['balanceUsd'];
    payments = [for (final p in (m['payments'] as List? ?? const [])) Payment.fromMap(Map<String, dynamic>.from(p))];
    invoiceNo = m['invoiceNo'];
    invoiceDate = m['invoiceDate'];
    priceNote = m['priceNote'];
    return this;
  }

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
        'breakfast': breakfast,
        'pets': pets,
        'crib': crib,
        'notes': notes,
        'reservedAt': reservedAt,
        'warnings': warnings,
        'source': source,
        'groupId': groupId,
        'beds': {for (final e in beds.entries) '${e.key}': e.value},
        'cleaningNote': cleaningNote,
      };

  factory Reservation.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) => Reservation.fromMap(d.data() ?? {}, id: d.id);

  /// Lee también los campos de plata si vienen en el mismo mapa (importación).
  factory Reservation.fromMap(Map<String, dynamic> m, {String? id}) => Reservation._fromMap(m, id: id).withMoney(m);

  factory Reservation._fromMap(Map<String, dynamic> m, {String? id}) => Reservation(
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
        breakfast: m['breakfast'] ?? false,
        pets: m['pets'] ?? false,
        crib: m['crib'] ?? false,
        notes: m['notes'],
        reservedAt: m['reservedAt'],
        warnings: List<String>.from(m['warnings'] ?? const []),
        source: m['source'],
        groupId: m['groupId'],
        beds: {for (final e in (m['beds'] as Map? ?? const {}).entries) int.parse('${e.key}'): (e.value as num).toInt()},
        cleaningNote: m['cleaningNote'],
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
    this.assignedTo,
    this.assignedName,
    this.dueDate,
    this.repeatDays,
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
  String? assignedTo; // uid de quien lo tiene que hacer; null = cualquiera
  String? assignedName;
  String? dueDate; // para cuándo
  int? repeatDays; // al marcarla hecha se crea la próxima

  bool get isOpen => status != MStatus.hecho;
  bool dueBy(String day) => isOpen && dueDate != null && dueDate!.compareTo(day) <= 0;
  bool isFor(String? uid) => assignedTo == null || assignedTo == uid;

  /// El costo va aparte, en maintenanceCosts/{id}, para que el staff no lo vea.
  Map<String, dynamic> toMap() => {
        'area': area,
        'title': title,
        'date': date,
        'description': description,
        'provider': provider,
        'status': status.name,
        'kind': kind,
        'createdBy': createdBy,
        'assignedTo': assignedTo,
        'assignedName': assignedName,
        'dueDate': dueDate,
        'repeatDays': repeatDays,
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
      assignedTo: m['assignedTo'],
      assignedName: m['assignedName'],
      dueDate: m['dueDate'],
      repeatDays: (m['repeatDays'] as num?)?.toInt(),
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
    this.purchaseId,
    this.createdBy,
  });
  String? id;
  String date;
  String detail;
  num amount; // positivo ingreso, negativo egreso
  String account;
  String category;
  String? reservationId;
  String? purchaseId;
  String? createdBy;

  bool get isIncome => amount >= 0;

  Map<String, dynamic> toMap() => {
        'date': date,
        'detail': detail,
        'amount': amount,
        'account': account,
        'category': category,
        'reservationId': reservationId,
        'purchaseId': ?purchaseId,
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
      purchaseId: m['purchaseId'],
      createdBy: m['createdBy'],
    );
  }
}

// ---------- Limpieza ----------

/// Una salida o una llegada en una cabaña, sin datos del huésped. Se arma al
/// guardar reservas y se publica en housekeeping/schedule para las mucamas.
class CleaningEvent {
  CleaningEvent({
    required this.date,
    required this.cabin,
    required this.arrival,
    this.people,
    this.beds,
    this.crib = false,
    this.pets = false,
    this.note,
    this.nights,
    this.tentative = false,
  });
  final String date;
  final int cabin;
  final bool arrival; // false = se van
  final int? people;
  final String? beds; // "1 matrimonial + 3 simples"; null = sin definir
  final bool crib;
  final bool pets;
  final String? note;
  final int? nights;
  final bool tentative; // consulta sin seña

  /// Id del documento en cleaning/ que marca si ya está hecho.
  String get key => '${date}_${cabin}_${arrival ? 'in' : 'out'}';

  Map<String, dynamic> toMap() => {
        'd': date,
        'c': cabin,
        'a': arrival,
        'p': ?people,
        'b': ?beds,
        if (crib) 'crib': true,
        if (pets) 'pets': true,
        'n': ?note,
        'nights': ?nights,
        if (tentative) 't': true,
      };

  factory CleaningEvent.fromMap(Map<String, dynamic> m) => CleaningEvent(
        date: m['d'],
        cabin: m['c'],
        arrival: m['a'] ?? false,
        people: m['p'],
        beds: m['b'],
        crib: m['crib'] ?? false,
        pets: m['pets'] ?? false,
        note: m['n'],
        nights: m['nights'],
        tentative: m['t'] ?? false,
      );
}

/// Indicación suelta para las mucamas ("repasar vidrios de la 3").
class CleaningTask {
  CleaningTask({this.id, required this.date, required this.text, this.cabin, this.done = false, this.createdBy, this.createdName});
  String? id;
  String date;
  String text;
  int? cabin;
  bool done;
  String? createdBy;
  String? createdName;

  Map<String, dynamic> toMap() => {'date': date, 'text': text, 'cabin': cabin, 'done': done, 'createdBy': createdBy, 'createdName': createdName};

  factory CleaningTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return CleaningTask(
      id: d.id,
      date: m['date'] ?? ymd(today()),
      text: m['text'] ?? '',
      cabin: (m['cabin'] as num?)?.toInt(),
      done: m['done'] ?? false,
      createdBy: m['createdBy'],
      createdName: m['createdName'],
    );
  }
}

// ---------- Compras ----------

enum PStatus { pedido, comprado, entregado, cancelado }

String pStatusLabel(PStatus s) => switch (s) {
      PStatus.pedido => 'Pedido',
      PStatus.comprado => 'Comprado',
      PStatus.entregado => 'Entregado',
      PStatus.cancelado => 'Cancelado',
    };

/// Lo que el personal necesita comprar. El costo no se guarda acá: va a la
/// caja como gasto (movements, con purchaseId) para que el staff no lo vea.
class Purchase {
  Purchase({
    this.id,
    required this.item,
    this.qty,
    this.area,
    this.maintenanceId,
    this.maintenanceTitle,
    this.note,
    this.status = PStatus.pedido,
    this.requestedBy,
    this.requestedName,
    String? createdAt,
    this.boughtAt,
    this.movementId,
  }) : createdAt = createdAt ?? ymd(today());
  String? id;
  String item;
  String? qty;
  String? area; // mismo formato que en mantenimiento
  String? maintenanceId;
  String? maintenanceTitle;
  String? note;
  PStatus status;
  String? requestedBy;
  String? requestedName;
  String createdAt;
  String? boughtAt;
  String? movementId;

  bool get isOpen => status == PStatus.pedido || status == PStatus.comprado;

  Map<String, dynamic> toMap() => {
        'item': item,
        'qty': qty,
        'area': area,
        'maintenanceId': maintenanceId,
        'maintenanceTitle': maintenanceTitle,
        'note': note,
        'status': status.name,
        'requestedBy': requestedBy,
        'requestedName': requestedName,
        'createdAt': createdAt,
        'boughtAt': boughtAt,
        'movementId': movementId,
      };

  factory Purchase.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Purchase(
      id: d.id,
      item: m['item'] ?? '',
      qty: m['qty'],
      area: m['area'],
      maintenanceId: m['maintenanceId'],
      maintenanceTitle: m['maintenanceTitle'],
      note: m['note'],
      status: PStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => PStatus.pedido),
      requestedBy: m['requestedBy'],
      requestedName: m['requestedName'],
      createdAt: m['createdAt'],
      boughtAt: m['boughtAt'],
      movementId: m['movementId'],
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

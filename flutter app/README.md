# Martina Manuel · Gestión

App Flutter (web + Android) para manejar el complejo: reemplaza la planilla
`PLANILLA DE RESERVAS.xlsx` y el ida y vuelta por WhatsApp. Usa Firebase
(Auth + Firestore) y publica las noches ocupadas para el calendario de la web
(`../web`).

## Qué hace

| Pantalla | Reemplaza | Quién |
|---|---|---|
| **Hoy**: quién llega, quién se va, cabañas ocupadas esta noche, saldos a cobrar, consultas sin seña, mantenimiento pendiente | WhatsApp / memoria | todos |
| **Diagrama**: cabañas × noches del mes, con nombre y personas; tocar la primera y la última noche libre crea la reserva; feriados resaltados y % de ocupación | hoja `diagrama` | todos |
| **Reservas**: búsqueda, ficha con pagos, saldo, factura, canal, desayuno/mascota/cuna, mensajes de WhatsApp listos (confirmación, pedir seña, recordatorio, pedir opinión) | hojas `desarrollo …` | todos |
| **Mantenimiento**: historial por cabaña y por servicio (piscinas, jacuzzi, parque, fogón…), con costo, proveedor y estado | — (nuevo) | todos |
| **Caja**: saldos por cuenta (caja, Francés, Patagonia, MP Claudio, MP Euge, dólares), movimientos y gastos del mes por rubro. Los cobros de reservas entran solos | `CAJA`, `BANCO FRANCES`, `MERC. PAGO`, `GASTOS MENSUALES` | admin |
| **Números**: ocupación y facturación por mes, noches por cabaña, de dónde vienen las reservas | columna de % del diagrama | admin |
| **Usuarios**: alta (Google o usuario/contraseña), cambio de rol, desactivar, aprobar pedidos de acceso | — | admin |
| **Ajustes**: tarifas, horarios, datos para la seña, feriados, importar la planilla, republicar disponibilidad | — | admin |

Roles: **administrador** (todo) y **usuario** (diagrama, reservas, cobros y
mantenimiento; no ve la caja ni los números). Las reglas de `firestore.rules`
lo hacen cumplir también del lado del servidor.

El **primer** usuario que entra queda como administrador. Después, quien entra
con Google sin invitación queda "pendiente" hasta que un admin lo aprueba.

## Puesta en marcha (una sola vez)

1. **Proyecto Firebase**: en <https://console.firebase.google.com> crear un
   proyecto (plan gratuito Spark alcanza).
   - *Authentication → Sign-in method*: activar **Google** y **Correo/contraseña**.
   - *Firestore Database*: crear la base (región `southamerica-east1`).
2. **Conectar la app** (genera `lib/firebase_options.dart` y `android/app/google-services.json`):
   ```sh
   dart pub global activate flutterfire_cli
   flutterfire configure --platforms=web,android
   ```
3. **Reglas de seguridad**:
   ```sh
   firebase use --add            # elegir el proyecto
   firebase deploy --only firestore:rules
   ```
4. **Google en Android**: registrar la huella SHA-1 en *Configuración del
   proyecto → Android*:
   ```sh
   cd android && ./gradlew signingReport
   ```
5. **Publicar la versión web de la app** (queda en `https://<proyecto>.web.app`):
   ```sh
   flutter build web --release
   firebase deploy --only hosting
   ```
   Si la app se publica en otro dominio, agregarlo en *Authentication →
   Settings → Authorized domains* para que funcione Google.
6. **APK para el celular**: `flutter build apk --release` →
   `build/app/outputs/flutter-apk/app-release.apk`.
7. **Web pública**: en `../web/js/data.js` poner `firebaseProjectId: '<id del proyecto>'`.
   El calendario de reservas empieza a mostrar los días completos y las
   cabañas libres de cada rango.

## Importar la planilla

```sh
pip install openpyxl
python3 tools/importar_excel.py "../PLANILLA DE RESERVAS.xlsx" tools/importacion.json
```

Después, en la app: **Ajustes → Importar la planilla → Elegir importacion.json → Importar**.

- Cruza las hojas `desarrollo …` (montos, contacto, factura, canal) con el
  `diagrama` (qué cabaña y qué noches). Lo que sólo está en el diagrama entra
  con nombre y personas.
- Las inconsistencias (fechas que no coinciden entre hojas, reservas que se
  pisan, fechas mal tipeadas) quedan marcadas: aparecen en **Hoy → Para
  revisar** y en **Reservas → A revisar**.
- Volver a importar no pisa lo que ya se corrigió en la app, salvo que se
  active "Pisar las que ya estaban importadas".
- `tools/importacion.json` tiene datos personales de huéspedes: está en
  `.gitignore`, no subirlo a ningún lado.

## Probar sin tocar Firebase real

```sh
firebase emulators:start --only auth,firestore --project demo-martina-manuel
flutter run -d chrome --dart-define=EMULATOR=true
```

Usa el emulador local (Firestore en el puerto 8085) con las mismas reglas.

## Cómo se vincula con la web

Cada vez que se guarda, cancela o borra una reserva, la app escribe
`public/availability`: por cabaña, los rangos `[llegada, salida)` ocupados de
hoy en adelante, **sin nombres ni datos personales**. Es el único documento
de lectura pública; la web lo lee con la API REST de Firestore, sin SDK.

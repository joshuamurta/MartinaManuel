import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/alerts.dart';
import 'data/session.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'theme.dart';

/// `flutter run --dart-define=EMULATOR=true` usa los emuladores locales de
/// Firebase (`firebase emulators:start`) con un proyecto de prueba.
const useEmulator = bool.fromEnvironment('EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_AR');
  try {
    await Firebase.initializeApp(
      options: useEmulator
          ? const FirebaseOptions(apiKey: 'demo', appId: '1:1:web:1', messagingSenderId: '1', projectId: 'demo-martina-manuel')
          : DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError catch (e) {
    runApp(_SetupMissing(e.message ?? '$e'));
    return;
  }
  if (useEmulator) {
    const host = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8085);
    // Para probar sin tipear: --dart-define=DEMO_LOGIN=email:contraseña
    const demo = String.fromEnvironment('DEMO_LOGIN');
    if (demo.contains(':') && FirebaseAuth.instance.currentUser == null) {
      final i = demo.indexOf(':');
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: demo.substring(0, i), password: demo.substring(i + 1));
    }
  }
  final session = Session();
  runApp(MartinaManuelApp(session: session, alerts: Alerts(session)));
}

class MartinaManuelApp extends StatefulWidget {
  const MartinaManuelApp({super.key, required this.session, required this.alerts});
  final Session session;
  final Alerts alerts;

  @override
  State<MartinaManuelApp> createState() => _MartinaManuelAppState();
}

class _MartinaManuelAppState extends State<MartinaManuelApp> {
  late final router = buildRouter(widget.session);

  @override
  Widget build(BuildContext context) => SessionScope(
        session: widget.session,
        child: AlertsScope(
          alerts: widget.alerts,
          child: MaterialApp.router(
            title: 'Martina Manuel · Gestión',
            debugShowCheckedModeBanner: false,
            theme: MM.theme(),
            routerConfig: router,
            locale: const Locale('es', 'AR'),
            supportedLocales: const [Locale('es', 'AR'), Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
          ),
        ),
      );
}

/// Da acceso a la sesión desde cualquier pantalla: `SessionScope.of(context)`.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child}) : super(notifier: session);

  static Session of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}

/// Avisos de la app: `AlertsScope.of(context).items`.
class AlertsScope extends InheritedNotifier<Alerts> {
  const AlertsScope({super.key, required Alerts alerts, required super.child}) : super(notifier: alerts);

  static Alerts of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AlertsScope>()!.notifier!;
}

class _SetupMissing extends StatelessWidget {
  const _SetupMissing(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: MM.theme(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const BrandMark(size: 64),
                const SizedBox(height: 20),
                Text('Falta conectar Firebase', style: MM.display(28)),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}

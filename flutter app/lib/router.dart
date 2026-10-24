import 'package:go_router/go_router.dart';

import 'data/session.dart';
import 'screens/cash_screen.dart';
import 'screens/diagram_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/reservation_detail_screen.dart';
import 'screens/reservation_form_screen.dart';
import 'screens/reservations_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/users_screen.dart';
import 'widgets/shell.dart';

const adminOnly = {'/caja', '/numeros', '/usuarios', '/ajustes'};

GoRouter buildRouter(Session session) => GoRouter(
      refreshListenable: session,
      initialLocation: '/',
      redirect: (context, state) {
        final loc = state.matchedLocation;
        const gates = {'/cargando', '/login', '/pendiente'};
        // Al pasar por carga/ingreso se recuerda adónde iba (enlace directo o recarga).
        final target = gates.contains(loc) ? state.uri.queryParameters['ir'] : state.uri.toString();
        String gate(String path) => path == loc ? state.uri.toString() : Uri(path: path, queryParameters: {if (target != null && target != '/') 'ir': target}).toString();
        if (session.loading) return gate('/cargando');
        if (!session.signedIn) return gate('/login');
        if (!session.canWork) return gate('/pendiente');
        if (gates.contains(loc)) return target ?? '/';
        if (adminOnly.any(loc.startsWith) && !session.isAdmin) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/cargando', builder: (_, _) => const LoadingScreen()),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/pendiente', builder: (_, _) => const PendingScreen()),
        ShellRoute(
          builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
          routes: [
            GoRoute(path: '/', pageBuilder: (_, _) => const NoTransitionPage(child: HomeScreen())),
            GoRoute(path: '/diagrama', pageBuilder: (_, _) => const NoTransitionPage(child: DiagramScreen())),
            GoRoute(
              path: '/reservas',
              pageBuilder: (_, _) => const NoTransitionPage(child: ReservationsScreen()),
              routes: [
                GoRoute(
                  path: 'nueva',
                  builder: (_, s) => ReservationFormScreen(
                    cabin: int.tryParse(s.uri.queryParameters['cabin'] ?? ''),
                    checkIn: s.uri.queryParameters['in'],
                    checkOut: s.uri.queryParameters['out'],
                  ),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, s) => ReservationDetailScreen(id: s.pathParameters['id']!),
                  routes: [
                    GoRoute(path: 'editar', builder: (_, s) => ReservationFormScreen(id: s.pathParameters['id'])),
                  ],
                ),
              ],
            ),
            GoRoute(path: '/mantenimiento', pageBuilder: (_, _) => const NoTransitionPage(child: MaintenanceScreen())),
            GoRoute(path: '/caja', pageBuilder: (_, _) => const NoTransitionPage(child: CashScreen())),
            GoRoute(path: '/numeros', pageBuilder: (_, _) => const NoTransitionPage(child: ReportsScreen())),
            GoRoute(path: '/usuarios', pageBuilder: (_, _) => const NoTransitionPage(child: UsersScreen())),
            GoRoute(path: '/ajustes', pageBuilder: (_, _) => const NoTransitionPage(child: SettingsScreen())),
          ],
        ),
      ],
    );

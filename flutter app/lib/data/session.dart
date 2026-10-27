import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models.dart';
import 'repo.dart';

/// Quién está usando la app y con qué rol. El router escucha este objeto.
class Session extends ChangeNotifier {
  Session() {
    _authSub = _auth.authStateChanges().listen(_onAuth);
    // Al volver del login de Google (redirección) muestra el error si lo hubo.
    if (kIsWeb) {
      _auth.getRedirectResult().then((_) {}, onError: (Object e) {
        error = authErrorText(e);
        notifyListeners();
      });
    }
  }

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  bool loading = true;
  User? authUser;
  AppUser? profile;
  String? error;

  bool get signedIn => authUser != null;
  bool get isAdmin => profile?.isAdmin ?? false;
  bool get canWork => profile?.canWork ?? false;
  Perms get perms => profile?.perms ?? Perms.none;

  Future<void> _onAuth(User? user) async {
    await _profileSub?.cancel();
    authUser = user;
    profile = null;
    Repo.instance.perms = Perms.none;
    error = null;
    if (user == null) {
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      await _ensureProfile(user);
      _profileSub = _db.doc('users/${user.uid}').snapshots().listen((d) {
        profile = d.exists ? AppUser.fromDoc(d) : null;
        Repo.instance.perms = perms;
        loading = false;
        notifyListeners();
      });
    } catch (e) {
      error = 'No pudimos cargar tu perfil: $e';
      loading = false;
      notifyListeners();
    }
  }

  /// Primer ingreso: si un admin lo invitó toma ese rol; si nadie configuró la
  /// app todavía queda como administrador; si no, espera aprobación.
  Future<void> _ensureProfile(User user) async {
    final ref = _db.doc('users/${user.uid}');
    if ((await ref.get()).exists) return;

    final email = (user.email ?? '').toLowerCase();
    final base = {
      'email': email,
      'name': user.displayName ?? email.split('@').first,
      'active': true,
      'provider': user.providerData.isNotEmpty ? user.providerData.first.providerId : 'password',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final invite = email.isEmpty ? null : await _db.doc('invites/$email').get();
    if (invite != null && invite.exists) {
      final inv = invite.data()!;
      final batch = _db.batch()
        ..set(ref, {
          ...base,
          'role': inv['role'] ?? Role.encargado.name,
          if (inv['name'] != null) 'name': inv['name'],
          if (inv['perms'] != null) 'perms': inv['perms'],
        })
        ..delete(invite.reference);
      await batch.commit();
      return;
    }

    final setup = await _db.doc('meta/setup').get();
    if (!setup.exists) {
      final batch = _db.batch()
        ..set(ref, {...base, 'role': 'admin'})
        ..set(setup.reference, {'firstAdmin': user.uid, 'at': FieldValue.serverTimestamp()});
      await batch.commit();
      return;
    }

    await ref.set({...base, 'role': 'pending'});
  }

  // ---------- Ingreso ----------

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    if (kIsWeb) {
      // Redirección en la misma pestaña: las ventanas emergentes fallan en
      // muchos navegadores de celular. Al volver, authStateChanges ya trae al usuario.
      await _auth.signInWithRedirect(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  /// Crea una cuenta con email y contraseña sin cerrar la sesión del admin:
  /// usa una segunda instancia de Firebase sólo para el alta.
  static Future<String> createPasswordAccount(String email, String password) async {
    final app = Firebase.apps.any((a) => a.name == 'alta-usuarios')
        ? Firebase.app('alta-usuarios')
        : await Firebase.initializeApp(name: 'alta-usuarios', options: DefaultFirebaseOptions.currentPlatform);
    final auth = FirebaseAuth.instanceFor(app: app);
    try {
      final cred = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      return cred.user!.uid;
    } finally {
      await auth.signOut();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

String authErrorText(Object e) {
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'invalid-credential' || 'wrong-password' || 'user-not-found' => 'El email o la contraseña no coinciden.',
      'invalid-email' => 'Revisá el email.',
      'too-many-requests' => 'Demasiados intentos. Probá en unos minutos.',
      'email-already-in-use' => 'Ya existe una cuenta con ese email.',
      'weak-password' => 'La contraseña tiene que tener al menos 6 caracteres.',
      'popup-closed-by-user' || 'canceled' || 'web-context-canceled' => 'Se cerró la ventana de Google.',
      'network-request-failed' => 'Sin conexión. Revisá internet.',
      _ => e.message ?? e.code,
    };
  }
  return e.toString();
}

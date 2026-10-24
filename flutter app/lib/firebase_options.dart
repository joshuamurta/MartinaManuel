// Archivo provisorio: se reemplaza al correr `flutterfire configure`
// (ver README.md). Hasta entonces la app muestra cómo configurarla.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      throw UnsupportedError('Firebase todavía no está configurado. Corré `flutterfire configure` (ver README.md).');
}

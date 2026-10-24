import 'package:flutter/material.dart';

import '../data/session.dart';
import '../main.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Escribí tu email y tocá de nuevo "Olvidé mi contraseña".');
      return;
    }
    await _run(() => SessionScope.of(context).resetPassword(_email.text));
    if (mounted && _error == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Te mandamos un email para elegir una contraseña nueva.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 860;

    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const BrandMark(size: 44),
                const SizedBox(width: 12),
                Text('Martina Manuel', style: MM.display(24)),
              ]),
              const SizedBox(height: 28),
              const Align(alignment: Alignment.centerLeft, child: Sticker('Gestión del complejo')),
              const SizedBox(height: 14),
              Text('Entrá para ver\nel diagrama', style: MM.display(34)),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(session.signInWithGoogle),
                icon: const _GoogleG(),
                label: const Text('Entrar con Google'),
              ),
              const SizedBox(height: 20),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('o con tu usuario', style: MM.label())),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 20),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v ?? '').contains('@') ? null : 'Escribí tu email',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass,
                obscureText: _hide,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: IconButton(
                    tooltip: _hide ? 'Mostrar' : 'Ocultar',
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) => (v ?? '').isEmpty ? 'Escribí tu contraseña' : null,
                onFieldSubmitted: (_) => _submit(session),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _busy ? null : _forgot, child: const Text('Olvidé mi contraseña')),
              ),
              if ((_error ?? session.error) != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text((_error ?? session.error)!, style: const TextStyle(color: MM.canyon, fontWeight: FontWeight.w600)),
                ),
              FilledButton(
                onPressed: _busy ? null : () => _submit(session),
                child: _busy
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: MM.cream))
                    : const Text('Entrar'),
              ),
              const SizedBox(height: 16),
              Text(
                'Las cuentas con usuario y contraseña las crea un administrador. Si entrás con Google por primera vez, un administrador tiene que aprobarte.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: MM.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );

    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: AutofillGroup(child: card)),
      ),
    );

    if (!wide) {
      return Scaffold(
        body: Stack(children: [
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.transparent],
                stops: [.0, .55],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: Image.asset('assets/img/hero.webp', fit: BoxFit.cover, alignment: Alignment.topCenter),
            ),
          ),
          SafeArea(child: form),
        ]),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(children: [
          Expanded(
            flex: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(fit: StackFit.expand, children: [
                Image.asset('assets/img/hero.webp', fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [Color(0x8C0A1E28), Colors.transparent],
                    ),
                  ),
                ),
                Positioned(
                  left: 48,
                  bottom: 48,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Sticker('Cañón del Atuel'),
                    const SizedBox(height: 14),
                    Text('Vení a escuchar\nel río', style: MM.display(64, color: MM.cream)),
                  ]),
                ),
              ]),
            ),
          ),
          Expanded(flex: 5, child: form),
        ]),
      ),
    );
  }

  void _submit(Session session) {
    if (_form.currentState!.validate()) _run(() => session.signInWithEmail(_email.text, _pass.text));
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) => Text('G',
      style: MM.display(18).copyWith(
            foreground: Paint()
              ..shader = const SweepGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335), Color(0xFF4285F4)])
                  .createShader(const Rect.fromLTWH(0, 0, 14, 18)),
          ));
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [BrandMark(size: 56), SizedBox(height: 24), CircularProgressIndicator()])),
      );
}

class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final p = session.profile;
    final msg = session.error ??
        (p != null && !p.active
            ? 'Tu usuario está desactivado. Si es un error, hablá con Eugenia o Claudio.'
            : 'Ya registramos tu cuenta (${session.authUser?.email}). Falta que un administrador te dé acceso; cuando lo haga, esta pantalla se actualiza sola.');
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const BrandMark(size: 52),
              const SizedBox(height: 24),
              const Sticker('Casi listo'),
              const SizedBox(height: 14),
              Text('Esperando\naprobación', style: MM.display(40)),
              const SizedBox(height: 16),
              Text(msg, style: const TextStyle(fontSize: 16, height: 1.5)),
              const SizedBox(height: 24),
              OutlinedButton(onPressed: session.signOut, child: const Text('Salir y entrar con otra cuenta')),
            ]),
          ),
        ),
      ),
    );
  }
}

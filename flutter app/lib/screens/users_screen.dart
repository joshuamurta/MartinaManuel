import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../data/session.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Alta, baja y modificación de usuarios (sólo administradores).
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = SessionScope.of(context).profile;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (_) => const _NewUserDialog()),
        backgroundColor: MM.ink,
        foregroundColor: MM.cream,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Agregar usuario'),
      ),
      body: StreamView<List<AppUser>>(
        stream: Repo.instance.users(),
        builder: (context, users) {
          final pending = users.where((u) => u.role == Role.pending).toList();
          final rest = users.where((u) => u.role != Role.pending).toList();
          return PageBody(maxWidth: 900, children: [
            const SectionHead(sticker: 'Usuarios', title: 'Quién usa la app'),
            const Text(
              'Administrador: ve todo, incluida la caja, los números y los ajustes. Usuario: diagrama, reservas, cobros y mantenimiento.',
              style: TextStyle(color: MM.inkSoft),
            ),
            if (pending.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 8), child: Text('PIDEN ACCESO', style: MM.label(color: MM.canyon))),
              Card(
                child: Column(children: [
                  for (final u in pending)
                    ListTile(
                      leading: const Icon(Icons.hourglass_top, color: MM.canyon),
                      title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(u.email),
                      trailing: Wrap(spacing: 4, children: [
                        TextButton(onPressed: () => Repo.instance.deleteUserProfile(u.uid), child: const Text('Rechazar')),
                        FilledButton(onPressed: () => Repo.instance.updateUser(u.uid, role: Role.user), child: const Text('Aprobar')),
                      ]),
                    ),
                ]),
              ),
            ],
            Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 8), child: Text('USUARIOS', style: MM.label())),
            Card(
              child: Column(children: [
                for (final (i, u) in rest.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _UserTile(user: u, isMe: u.uid == me?.uid),
                ],
              ]),
            ),
            StreamView<List<Map<String, dynamic>>>(
              stream: Repo.instance.invites(),
              builder: (context, invites) => invites.isEmpty
                  ? const SizedBox.shrink()
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 8), child: Text('INVITACIONES SIN USAR', style: MM.label())),
                      Card(
                        child: Column(children: [
                          for (final inv in invites)
                            ListTile(
                              leading: const Icon(Icons.mail_outline),
                              title: Text(inv['name'] ?? inv['email']),
                              subtitle: Text('${inv['email']} · ${roleLabel(roleFrom(inv['role']))} · entra con Google'),
                              trailing: IconButton(
                                tooltip: 'Borrar invitación',
                                icon: const Icon(Icons.close),
                                onPressed: () => Repo.instance.deleteInvite(inv['email']),
                              ),
                            ),
                        ]),
                      ),
                    ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.isMe});
  final AppUser user;
  final bool isMe;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(
          backgroundColor: user.active ? (user.role == Role.admin ? MM.ink : MM.sauce) : MM.sand,
          child: Text(
            user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase(),
            style: MM.display(16, color: user.role == Role.admin && user.active ? MM.cream : MM.ink),
          ),
        ),
        title: Text('${user.name}${isMe ? ' (vos)' : ''}', style: TextStyle(fontWeight: FontWeight.w700, color: user.active ? MM.ink : MM.inkSoft)),
        subtitle: Text('${user.email} · ${user.provider == 'google.com' ? 'Google' : 'usuario y contraseña'}${user.active ? '' : ' · desactivado'}'),
        trailing: isMe
            ? InfoChip(roleLabel(user.role))
            : PopupMenuButton<String>(
                tooltip: 'Opciones',
                onSelected: (v) => _action(context, v),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'role', child: Text(user.role == Role.admin ? 'Pasar a usuario' : 'Hacer administrador')),
                  const PopupMenuItem(value: 'name', child: Text('Cambiar nombre')),
                  if (user.provider != 'google.com') const PopupMenuItem(value: 'reset', child: Text('Mandar email para cambiar contraseña')),
                  PopupMenuItem(value: 'active', child: Text(user.active ? 'Desactivar' : 'Activar')),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: MM.canyon))),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [InfoChip(roleLabel(user.role)), const Icon(Icons.more_vert)]),
                ),
              ),
      );

  Future<void> _action(BuildContext context, String v) async {
    final repo = Repo.instance;
    switch (v) {
      case 'role':
        await repo.updateUser(user.uid, role: user.role == Role.admin ? Role.user : Role.admin);
      case 'active':
        await repo.updateUser(user.uid, active: !user.active);
      case 'reset':
        await SessionScope.of(context).resetPassword(user.email);
        if (context.mounted) toast(context, 'Le mandamos a ${user.email} un email para elegir contraseña.');
      case 'name':
        final c = TextEditingController(text: user.name);
        final name = await showDialog<String>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('Nombre'),
            content: TextField(controller: c, autofocus: true),
            actions: [FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Guardar'))],
          ),
        );
        if (name != null && name.isNotEmpty) await repo.updateUser(user.uid, name: name);
      case 'delete':
        if (context.mounted &&
            await confirm(context, 'Eliminar usuario', '${user.name} deja de tener acceso. Si vuelve a entrar va a quedar pendiente de aprobación.',
                ok: 'Eliminar', danger: true)) {
          await repo.deleteUserProfile(user.uid);
        }
    }
  }
}

class _NewUserDialog extends StatefulWidget {
  const _NewUserDialog();

  @override
  State<_NewUserDialog> createState() => _NewUserDialogState();
}

class _NewUserDialogState extends State<_NewUserDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  Role _role = Role.user;
  bool _google = true;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final email = _email.text.trim().toLowerCase();
    if (_name.text.trim().isEmpty || !email.contains('@')) {
      setState(() => _error = 'Completá nombre y email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_google) {
        await Repo.instance.invite(email, _name.text.trim(), _role);
      } else {
        final uid = await Session.createPasswordAccount(email, _pass.text);
        await Repo.instance.createUserProfile(uid, email, _name.text.trim(), _role);
      }
      if (mounted) {
        Navigator.pop(context);
        toast(
          context,
          _google
              ? 'Listo: cuando $email entre con Google va a tener acceso.'
              : 'Usuario creado. Pasale el email y la contraseña a ${_name.text.trim()}.',
        );
      }
    } catch (e) {
      setState(() => _error = authErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Agregar usuario', style: MM.display(24)),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Entra con Google')),
                ButtonSegment(value: false, label: Text('Usuario y contraseña')),
              ],
              selected: {_google},
              onSelectionChanged: (s) => setState(() => _google = s.first),
            ),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 12),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            if (!_google) ...[
              const SizedBox(height: 12),
              TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Contraseña inicial', helperText: 'Mínimo 6 caracteres')),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<Role>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: const [
                DropdownMenuItem(value: Role.user, child: Text('Usuario')),
                DropdownMenuItem(value: Role.admin, child: Text('Administrador')),
              ],
              onChanged: (v) => setState(() => _role = v ?? Role.user),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: MM.canyon))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Guardando…' : 'Agregar')),
        ],
      );
}

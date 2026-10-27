import 'package:flutter/foundation.dart';
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
              'Administrador: ve y hace todo. Encargado: diagrama, reservas y mantenimiento, sin montos ni caja. '
              'Staff: sólo mantenimiento, sin costos. Tocá un usuario para ajustar qué ve y qué puede hacer.',
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
                        FilledButton(onPressed: () => showPermsSheet(context, u), child: const Text('Aprobar')),
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
        onTap: isMe ? null : () => showPermsSheet(context, user),
        leading: CircleAvatar(
          backgroundColor: user.active ? (user.role == Role.admin ? MM.ink : MM.sauce) : MM.sand,
          child: Text(
            user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase(),
            style: MM.display(16, color: user.role == Role.admin && user.active ? MM.cream : MM.ink),
          ),
        ),
        title: Text('${user.name}${isMe ? ' (vos)' : ''}', style: TextStyle(fontWeight: FontWeight.w700, color: user.active ? MM.ink : MM.inkSoft)),
        subtitle: Text([
          user.email,
          user.provider == 'google.com' ? 'Google' : 'usuario y contraseña',
          if (user.customPerms != null && user.role != Role.admin) 'permisos a medida',
          if (!user.active) 'desactivado',
        ].join(' · ')),
        trailing: isMe
            ? InfoChip(roleLabel(user.role))
            : PopupMenuButton<String>(
                tooltip: 'Opciones',
                onSelected: (v) => _action(context, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'perms', child: Text('Rol y permisos')),
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
      case 'perms':
        await showPermsSheet(context, user);
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
  Role _role = Role.encargado;
  Map<String, int> _perms = defaultPerms(Role.encargado);
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
        await Repo.instance.invite(email, _name.text.trim(), _role, perms: customPerms(_role, _perms));
      } else {
        final uid = await Session.createPasswordAccount(email, _pass.text);
        await Repo.instance.createUserProfile(uid, email, _name.text.trim(), _role, perms: customPerms(_role, _perms));
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
          child: SingleChildScrollView(
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
            const SizedBox(height: 16),
            PermsEditor(
              role: _role,
              perms: _perms,
              onChanged: (role, perms) => setState(() {
                _role = role;
                _perms = perms;
              }),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: MM.canyon))),
          ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Guardando…' : 'Agregar')),
        ],
      );
}

/// Permisos a guardar: null si son los del rol (o si es admin, que ve todo).
Map<String, int>? customPerms(Role role, Map<String, int> perms) {
  if (role == Role.admin) return null;
  Map<String, int> clean(Map<String, int> m) => {for (final e in m.entries) if (e.value > 0) e.key: e.value};
  final p = clean(perms);
  return mapEquals(p, clean(defaultPerms(role))) ? null : p;
}

/// Rol y permisos de un usuario; al aprobar uno pendiente arranca como encargado.
Future<void> showPermsSheet(BuildContext context, AppUser user) async {
  var role = user.role == Role.pending ? Role.encargado : user.role;
  var perms = {...(user.customPerms ?? defaultPerms(role))};
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(user.name, style: MM.display(26)),
            Text(user.email, style: const TextStyle(color: MM.inkSoft)),
            const SizedBox(height: 16),
            PermsEditor(
              role: role,
              perms: perms,
              onChanged: (r, p) => setSheet(() {
                role = r;
                perms = p;
              }),
            ),
            const SizedBox(height: 20),
            Row(children: [
              if (role != Role.admin)
                TextButton(
                  onPressed: () => setSheet(() => perms = defaultPerms(role)),
                  child: const Text('Volver a los del rol'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(sheet);
                  final custom = customPerms(role, perms);
                  await Repo.instance.updateUser(user.uid, role: role, perms: custom, resetPerms: custom == null);
                },
                child: Text(user.role == Role.pending ? 'Aprobar' : 'Guardar'),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}

/// Elige el rol (que carga sus permisos por defecto) y ajusta cada sección.
class PermsEditor extends StatelessWidget {
  const PermsEditor({super.key, required this.role, required this.perms, required this.onChanged});
  final Role role;
  final Map<String, int> perms;
  final void Function(Role role, Map<String, int> perms) onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<Role>(
          segments: [for (final r in [Role.admin, Role.encargado, Role.staff]) ButtonSegment(value: r, label: Text(roleLabel(r)))],
          selected: {role},
          onSelectionChanged: (s) => onChanged(s.first, defaultPerms(s.first)),
        ),
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(roleHelp(role), style: const TextStyle(color: MM.inkSoft))),
        if (role != Role.admin) ...[
          Padding(padding: const EdgeInsets.fromLTRB(2, 18, 2, 4), child: Text('QUÉ VE Y QUÉ PUEDE HACER', style: MM.label())),
          for (final d in permDefs)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(d.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(d.help, style: const TextStyle(color: MM.inkSoft, fontSize: 12.5)),
                const SizedBox(height: 6),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [for (final e in d.levels.entries) ButtonSegment(value: e.key, label: Text(e.value))],
                  selected: {perms[d.key] ?? 0},
                  onSelectionChanged: (s) => onChanged(role, {...perms, d.key: s.first}),
                ),
              ]),
            ),
        ],
      ]);
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repo.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Lo que hace falta comprar: el personal lo pide, quien gestiona lo compra
/// y el gasto entra solo a la caja.
class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final manage = session.perms.canEdit('compras');
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => requestPurchase(context),
        backgroundColor: MM.ink,
        foregroundColor: MM.cream,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Pedir algo'),
      ),
      body: StreamView<List<Purchase>>(
        stream: Repo.instance.purchases(),
        builder: (context, all) {
          final asked = all.where((p) => p.status == PStatus.pedido).toList();
          final bought = all.where((p) => p.status == PStatus.comprado).toList();
          final history = all.where((p) => !p.isOpen).take(40).toList();
          return PageBody(maxWidth: 900, children: [
            const SectionHead(sticker: 'Compras', title: 'Lo que hace falta'),
            Text(
              manage
                  ? 'Al marcar algo como comprado podés cargar cuánto salió: queda como gasto en la caja.'
                  : 'Pedí lo que necesitás (cloro, lamparitas, repuestos…) y te avisamos cuando esté comprado.',
              style: const TextStyle(color: MM.inkSoft),
            ),
            _group(context, 'Pedidos', asked, manage, session.profile?.uid),
            _group(context, 'Comprados, falta entregar', bought, manage, session.profile?.uid),
            _group(context, 'Historial', history, manage, session.profile?.uid),
            if (all.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Todavía no se pidió nada.'))),
          ]);
        },
      ),
    );
  }

  Widget _group(BuildContext context, String title, List<Purchase> items, bool manage, String? uid) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 8), child: Text(title.toUpperCase(), style: MM.label())),
      Card(
        child: Column(children: [
          for (final (i, p) in items.indexed) ...[
            if (i > 0) const Divider(height: 1),
            _PurchaseTile(p: p, manage: manage, mine: p.requestedBy == uid),
          ],
        ]),
      ),
    ]);
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.p, required this.manage, required this.mine});
  final Purchase p;
  final bool manage;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final perms = SessionScope.of(context).perms;
    final actions = <String, String>{
      if (manage && p.status == PStatus.pedido) 'bought': 'Marcar comprado',
      if (p.status == PStatus.comprado) 'delivered': 'Marcar entregado',
      if ((manage || mine) && p.status == PStatus.pedido) 'edit': 'Corregir',
      if ((manage || mine) && p.status == PStatus.pedido) 'cancel': 'Cancelar pedido',
      if (manage && perms.delete) 'delete': 'Eliminar',
    };
    return ListTile(
      leading: Icon(
        switch (p.status) {
          PStatus.pedido => Icons.shopping_cart_outlined,
          PStatus.comprado => Icons.local_shipping_outlined,
          PStatus.entregado => Icons.check_circle,
          PStatus.cancelado => Icons.cancel_outlined,
        },
        color: p.isOpen ? MM.canyon : MM.forest,
      ),
      title: Text('${p.item}${(p.qty ?? '').isNotEmpty ? ' · ${p.qty}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text([
        if (p.requestedName != null) p.requestedName!,
        fmtShort(parseYmd(p.createdAt)),
        if (p.area != null) areaLabel(p.area!),
        if (p.maintenanceTitle != null) 'para: ${p.maintenanceTitle}',
        if ((p.note ?? '').isNotEmpty) p.note!,
        if (!p.isOpen) pStatusLabel(p.status),
      ].join(' · ')),
      trailing: actions.isEmpty
          ? null
          : PopupMenuButton<String>(
              tooltip: 'Opciones',
              onSelected: (v) => _action(context, v),
              itemBuilder: (_) => [
                for (final e in actions.entries)
                  PopupMenuItem(value: e.key, child: Text(e.value, style: e.key == 'delete' ? const TextStyle(color: MM.canyon) : null)),
              ],
            ),
    );
  }

  Future<void> _action(BuildContext context, String v) async {
    final repo = Repo.instance;
    switch (v) {
      case 'bought':
        await showDialog(context: context, builder: (_) => _BoughtDialog(p: p));
      case 'delivered':
        await repo.savePurchase(p..status = PStatus.entregado);
      case 'edit':
        await requestPurchase(context, existing: p);
      case 'cancel':
        await repo.savePurchase(p..status = PStatus.cancelado);
      case 'delete':
        if (await confirm(context, 'Eliminar pedido', 'Se borra "${p.item}". Si se cargó un gasto en la caja, queda ahí.', ok: 'Eliminar', danger: true)) {
          await repo.deletePurchase(p.id!);
        }
    }
  }
}

/// Pedir algo. Desde un arreglo de mantenimiento queda vinculado a él.
Future<void> requestPurchase(BuildContext context, {Purchase? existing, MaintenanceItem? forItem}) async {
  final p = existing ??
      Purchase(
        item: '',
        area: forItem?.area,
        maintenanceId: forItem?.id,
        maintenanceTitle: forItem?.title,
      );
  final item = TextEditingController(text: p.item);
  final qty = TextEditingController(text: p.qty ?? '');
  final note = TextEditingController(text: p.note ?? '');
  final areas = [for (final c in defaultCabins) 'cabin-${c.id}', ...maintenanceAreas.keys];
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheet).bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(existing == null ? 'Pedir algo' : 'Corregir pedido', style: MM.display(26)),
          if (p.maintenanceTitle != null) Text('Para: ${p.maintenanceTitle}', style: const TextStyle(color: MM.inkSoft)),
          const SizedBox(height: 16),
          TextField(controller: item, autofocus: existing == null, decoration: const InputDecoration(labelText: 'Qué hace falta', hintText: 'Cloro, lamparitas, flotante…')),
          const SizedBox(height: 12),
          TextField(controller: qty, decoration: const InputDecoration(labelText: 'Cuánto', hintText: '2 bidones, 1 caja…')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: p.area,
            decoration: const InputDecoration(labelText: 'Para dónde'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin indicar')),
              for (final a in areas) DropdownMenuItem(value: a, child: Text(areaLabel(a))),
            ],
            onChanged: (v) => p.area = v,
          ),
          const SizedBox(height: 12),
          TextField(controller: note, maxLines: 2, minLines: 1, decoration: const InputDecoration(labelText: 'Nota (marca, urgencia…)')),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () async {
                if (item.text.trim().isEmpty) return;
                p
                  ..item = item.text.trim()
                  ..qty = qty.text.trim()
                  ..note = note.text.trim();
                Navigator.pop(sheet);
                await Repo.instance.savePurchase(p);
                if (context.mounted && existing == null) toast(context, 'Pedido cargado. Le llega un aviso a quien compra.');
              },
              child: Text(existing == null ? 'Pedir' : 'Guardar'),
            ),
          ),
        ]),
      ),
    ),
  );
}

/// Al marcar comprado se puede cargar el gasto en la caja.
class _BoughtDialog extends StatefulWidget {
  const _BoughtDialog({required this.p});
  final Purchase p;

  @override
  State<_BoughtDialog> createState() => _BoughtDialogState();
}

class _BoughtDialogState extends State<_BoughtDialog> {
  final _amount = TextEditingController();
  String? _account = 'caja';
  late String _category = widget.p.maintenanceId != null ? 'Mantenimiento' : 'Otros';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Comprado: ${widget.p.item}', style: MM.display(22)),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Cuánto salió (opcional)', prefixText: r'$ '),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _account,
              decoration: const InputDecoration(labelText: 'De dónde salió la plata'),
              items: [
                for (final e in accounts.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                const DropdownMenuItem(value: null, child: Text('No cargar en la caja')),
              ],
              onChanged: (v) => setState(() => _account = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Rubro'),
              items: [for (final c in expenseCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => _category = v ?? _category,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await Repo.instance.markBought(widget.p, amount: num.tryParse(_amount.text), account: _account, category: _category);
            },
            child: const Text('Listo'),
          ),
        ],
      );
}

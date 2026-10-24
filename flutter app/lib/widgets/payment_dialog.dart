import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repo.dart';
import '../models.dart';
import '../theme.dart';

/// Pide monto, fecha y cuenta de un cobro. Con cuenta elegida el cobro entra
/// también a la caja.
Future<Payment?> showPaymentDialog(BuildContext context, {num? suggested}) => showDialog<Payment>(
      context: context,
      builder: (_) => _PaymentDialog(suggested: suggested),
    );

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({this.suggested});
  final num? suggested;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _amount = TextEditingController(text: widget.suggested?.round().toString() ?? '');
  final _note = TextEditingController();
  DateTime _date = today();
  String? _account = 'mp_euge';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Registrar pago', style: MM.display(22)),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Monto', prefixText: r'$ '),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2019), lastDate: DateTime(2035));
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(decoration: const InputDecoration(labelText: 'Fecha'), child: Text(fmtDay(_date))),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _account,
              decoration: const InputDecoration(labelText: 'Dónde entró la plata'),
              items: [
                for (final e in accounts.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                const DropdownMenuItem(value: null, child: Text('No cargar en la caja')),
              ],
              onChanged: (v) => setState(() => _account = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Nota (seña, saldo, transferencia…)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final amount = num.tryParse(_amount.text);
              if (amount == null || amount <= 0) return;
              Navigator.pop(
                context,
                Payment(id: Repo.instance.newPaymentId(), date: ymd(_date), amount: amount, account: _account, note: _note.text.trim()),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      );
}

import 'package:flutter/material.dart';
import '../../../data/models/coupon.dart';
import '../../../data/models/member.dart';

class CouponFormDialog extends StatefulWidget {
  final Coupon? initial;
  final List<Member> members;

  const CouponFormDialog({super.key, this.initial, required this.members});

  @override
  State<CouponFormDialog> createState() => _CouponFormDialogState();
}

class _CouponFormDialogState extends State<CouponFormDialog> {
  final _form = GlobalKey<FormState>();

  late TextEditingController code;
  String kind = 'percent';
  final valueCtrl = TextEditingController(text: '10');
  String scope = 'all';
  String appliesTo = 'all';
  String? memberId;
  DateTime? validFrom;
  DateTime? validTo;
  final maxRedCtrl = TextEditingController();
  bool active = true;

  @override
  void initState() {
    super.initState();
    code = TextEditingController(text: widget.initial?.code ?? '');
    kind = widget.initial?.kind ?? 'percent';
    valueCtrl.text = (widget.initial?.value ?? 10).toString();
    scope = widget.initial?.scope ?? 'all';
    appliesTo = widget.initial?.appliesTo ?? 'all';
    memberId = widget.initial?.memberId;
    validFrom = widget.initial?.validFrom;
    validTo = widget.initial?.validTo;
    maxRedCtrl.text = (widget.initial?.maxRedemptions ?? '').toString();
    active = widget.initial?.active ?? true;
  }

  @override
  void dispose() {
    code.dispose();
    valueCtrl.dispose();
    maxRedCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool from) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDate: now,
    );
    if (d == null) return;
    setState(() {
      if (from) validFrom = d;
      else validTo = d.add(const Duration(hours: 23, minutes: 59));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add coupon' : 'Edit coupon'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Code'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: kind,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('Percent %')),
                  DropdownMenuItem(value: 'fixed', child: Text('Fixed amount')),
                ],
                onChanged: (v) => setState(() => kind = v ?? 'percent'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: valueCtrl,
                decoration: const InputDecoration(labelText: 'Value'),
                keyboardType: TextInputType.number,
                validator: (v) => (num.tryParse(v ?? '') == null) ? 'Number' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: scope,
                decoration: const InputDecoration(labelText: 'Scope'),
                items: const [
                  DropdownMenuItem(value: 'drinks', child: Text('Drinks only')),
                  DropdownMenuItem(value: 'sessions', child: Text('Sessions only')),
                  DropdownMenuItem(value: 'all', child: Text('All')),
                ],
                onChanged: (v) => setState(() => scope = v ?? 'all'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: appliesTo,
                decoration: const InputDecoration(labelText: 'Applies to'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All members')),
                  DropdownMenuItem(value: 'member', child: Text('Specific member')),
                ],
                onChanged: (v) => setState(() => appliesTo = v ?? 'all'),
              ),
              if (appliesTo == 'member') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: memberId,
                  decoration: const InputDecoration(labelText: 'Member'),
                  items: widget.members
                      .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                      .toList(),
                  onChanged: (v) => setState(() => memberId = v),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(validFrom == null ? 'From: —' : 'From: ${validFrom!.toIso8601String().substring(0,10)}'),
                  ),
                  TextButton(onPressed: () => _pickDate(true), child: const Text('Pick')),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(validTo == null ? 'To: —' : 'To: ${validTo!.toIso8601String().substring(0,10)}'),
                  ),
                  TextButton(onPressed: () => _pickDate(false), child: const Text('Pick')),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: maxRedCtrl,
                decoration: const InputDecoration(labelText: 'Max redemptions (optional)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Active'),
                value: active,
                onChanged: (v) => setState(() => active = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            final c = Coupon(
              id: widget.initial?.id ?? '',
              code: code.text.trim(),
              kind: kind,
              value: num.parse(valueCtrl.text),
              scope: scope,
              appliesTo: appliesTo,
              memberId: appliesTo == 'member' ? memberId : null,
              validFrom: validFrom,
              validTo: validTo,
              maxRedemptions: int.tryParse(maxRedCtrl.text.trim().isEmpty ? '' : maxRedCtrl.text.trim()),
              active: active,
            );
            Navigator.pop<Coupon>(context, c);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

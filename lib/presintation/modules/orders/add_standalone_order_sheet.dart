import 'package:flutter/material.dart';
import '../../../data/models/app_settings.dart';

class AddStandaloneOrderSheet extends StatefulWidget {
  final List<DrinkItem> drinks;         // من settings
  const AddStandaloneOrderSheet({super.key, required this.drinks});

  @override
  State<AddStandaloneOrderSheet> createState() => _AddStandaloneOrderSheetState();
}

class _AddStandaloneOrderSheetState extends State<AddStandaloneOrderSheet> {
  final _form = GlobalKey<FormState>();
  final _customerCtrl = TextEditingController(text: 'Walk-in');
  final _customItemCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();

  bool _useCustom = false;
  DrinkItem? _selected;

  @override
  void dispose() {
    _customerCtrl.dispose();
    _customItemCtrl.dispose();
    _customPriceCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drinks = widget.drinks.where((d) => d.active).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('إضافة طلب مستقل', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              // اسم الزبون اليدوي
              TextFormField(
                controller: _customerCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم الزبون (مثلاً: Walk-in أو اسم سريع)',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                value: _useCustom,
                onChanged: (v) => setState(() => _useCustom = v),
                title: const Text('إدخال صنف وسعر يدوي'),
                contentPadding: EdgeInsets.zero,
              ),

              if (!_useCustom) ...[
                DropdownButtonFormField<DrinkItem>(
                  value: _selected,
                  decoration: const InputDecoration(labelText: 'المشروب'),
                  items: drinks
                      .map((d) => DropdownMenuItem(value: d, child: Text('${d.name} — ${d.price}')))
                      .toList(),
                  onChanged: (v) => setState(() => _selected = v),
                  validator: (v) => v == null ? 'اختر مشروب' : null,
                ),
              ] else ...[
                TextFormField(
                  controller: _customItemCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الصنف'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل اسم الصنف' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _customPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'سعر الوحدة'),
                  validator: (v) => (num.tryParse(v ?? '') == null) ? 'رقم' : null,
                ),
              ],
              const SizedBox(height: 8),

              TextFormField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية'),
                validator: (v) => (int.tryParse(v ?? '') == null || int.parse(v!) <= 0) ? 'عدد صحيح' : null,
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (!(_form.currentState?.validate() ?? false)) return;

                      final qty = int.parse(_qtyCtrl.text);
                      String itemName;
                      num unitPrice;

                      if (_useCustom) {
                        itemName = _customItemCtrl.text.trim();
                        unitPrice = num.parse(_customPriceCtrl.text);
                      } else {
                        itemName = _selected!.name;
                        unitPrice = _selected!.price;
                      }

                      Navigator.pop<Map<String, dynamic>>(context, {
                        'customerName': _customerCtrl.text.trim(),
                        'itemName': itemName,
                        'unitPriceAtTime': unitPrice,
                        'qty': qty,
                        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                      });
                    },
                    child: const Text('إضافة'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

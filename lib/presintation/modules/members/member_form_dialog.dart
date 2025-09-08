import 'package:flutter/material.dart';
import '../../../data/models/member.dart';

class MemberFormDialog extends StatefulWidget {
  final Member? initial;
  const MemberFormDialog({super.key, this.initial});

  @override
  State<MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<MemberFormDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController name;
  late TextEditingController phone;
  late TextEditingController notes;
  bool isActive = true;

  String? preferredPlan; // 'hour' | 'week' | 'month' | null

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initial?.name ?? '');
    phone = TextEditingController(text: widget.initial?.phone ?? '');
    notes = TextEditingController(text: widget.initial?.notes ?? '');
    isActive = widget.initial?.isActive ?? true;
    preferredPlan = widget.initial?.preferredPlan; // قد تكون null
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    notes.dispose();
    super.dispose();
  }

  Widget _planRadio(String value, String label) {
    return Expanded(
      child: RadioListTile<String>(
        dense: true,
        value: value,
        groupValue: preferredPlan,
        onChanged: (v) => setState(() => preferredPlan = v),
        title: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality( // ✅ جعل الحوار بالكامل من اليمين لليسار
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.initial == null ? 'إضافة عضو' : 'تعديل عضو'),
        content: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'إلزامي' : null,
                ),
                TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'الهاتف'),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'الخطة المفضلة (اختياري)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Row(
                  children: [
                    _planRadio('hour', 'بالساعة'),
                    _planRadio('week', 'أسبوعي'),
                    _planRadio('month', 'شهري'),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => setState(() => preferredPlan = null),
                    child: const Text('مسح الاختيار'),
                  ),
                ),
                SwitchListTile(
                  value: isActive,
                  onChanged: (v) => setState(() => isActive = v),
                  title: const Text('مُفعل'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (!(_form.currentState?.validate() ?? false)) return;
              Navigator.pop<Member>(
                context,
                Member(
                  id: widget.initial?.id ?? '',
                  name: name.text.trim(),
                  phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                  notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                  isActive: isActive,
                  preferredPlan: preferredPlan, // 👈
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

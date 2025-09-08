import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/member.dart';
import '../../../data/repositories/members_repo.dart';

class AddDebtResult {
  final String memberId;
  final String memberName;
  final num amount;
  final String reason;

  AddDebtResult({
    required this.memberId,
    required this.memberName,
    required this.amount,
    required this.reason,
  });
}

class AddDebtDialog extends StatefulWidget {
  final String? memberId;
  final String? memberName;
  const AddDebtDialog({super.key, this.memberId, this.memberName});

  @override
  State<AddDebtDialog> createState() => _AddDebtDialogState();
}

class _AddDebtDialogState extends State<AddDebtDialog> {
  final membersRepo = MembersRepo();
  final amountCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();

  String? selectedMemberId;
  String? selectedMemberName;
  String? errMember;
  String? errAmount;

  @override
  void initState() {
    super.initState();
    selectedMemberId = widget.memberId;
    selectedMemberName = widget.memberName;
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    reasonCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount =
        num.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    setState(() {
      errAmount = amount <= 0 ? 'أدخل مبلغاً أكبر من 0' : null;
      if (widget.memberId == null &&
          (selectedMemberId == null || selectedMemberName == null)) {
        errMember = 'اختر عضواً';
      } else {
        errMember = null;
      }
    });
    if (errAmount != null || errMember != null) return;
    Navigator.pop(
      context,
      AddDebtResult(
        memberId: selectedMemberId!,
        memberName: selectedMemberName ?? '',
        amount: amount,
        reason: reasonCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إضافة دين'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.memberId == null)
              StreamBuilder<List<Member>>(
                stream: membersRepo.watchAll(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final members = snap.data!;
                  return DropdownButtonFormField<String>(
                    value: selectedMemberId,
                    decoration: InputDecoration(
                      labelText: 'العضو',
                      prefixIcon: const Icon(Icons.person_outline),
                      errorText: errMember,
                    ),
                    items: members
                        .map(
                          (m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(m.name),
                      ),
                    )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedMemberId = v;
                        selectedMemberName =
                            members.firstWhere((m) => m.id == v).name;
                      });
                    },
                  );
                },
              )
            else
              Text(
                widget.memberName ?? '',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'المبلغ',
                prefixIcon: const Icon(Icons.payments_outlined),
                prefixText: '₪ ',
                errorText: errAmount,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'السبب',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
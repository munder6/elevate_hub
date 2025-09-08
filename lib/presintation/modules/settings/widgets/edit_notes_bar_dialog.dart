import 'package:flutter/material.dart';
import '../../../../data/models/app_settings.dart';

class EditNotesBarDialog extends StatefulWidget {
  final NotesBar initial;
  const EditNotesBarDialog({super.key, required this.initial});

  @override
  State<EditNotesBarDialog> createState() => _EditNotesBarDialogState();
}

class _EditNotesBarDialogState extends State<EditNotesBarDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController text;
  String priority = 'info';
  bool active = false;
  DateTime? startAt;
  DateTime? endAt;

  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: widget.initial.text);
    priority = widget.initial.priority;
    active = widget.initial.active;
    startAt = widget.initial.startAt;
    endAt = widget.initial.endAt;
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<DateTime?> pickDate(DateTime? initial) async {
    final now = DateTime.now();
    final base = initial ?? now;
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDate: base,
    );
    if (d == null) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (t == null) return DateTime(d.year, d.month, d.day);
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Top Notes Bar'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: text,
                decoration: const InputDecoration(labelText: 'Text'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: priority,
                items: const [
                  DropdownMenuItem(value: 'info', child: Text('info')),
                  DropdownMenuItem(value: 'warn', child: Text('warn')),
                  DropdownMenuItem(value: 'alert', child: Text('alert')),
                ],
                onChanged: (v) => setState(() => priority = v ?? 'info'),
                decoration: const InputDecoration(labelText: 'Priority'),
              ),
              SwitchListTile(
                value: active,
                onChanged: (v) => setState(() => active = v),
                title: const Text('Active'),
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start'),
                      subtitle: Text(startAt?.toString() ?? '—'),
                      onTap: () async {
                        final d = await pickDate(startAt);
                        setState(() => startAt = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End'),
                      subtitle: Text(endAt?.toString() ?? '—'),
                      onTap: () async {
                        final d = await pickDate(endAt);
                        setState(() => endAt = d);
                      },
                    ),
                  ),
                ],
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
            Navigator.pop<NotesBar>(
              context,
              NotesBar(
                text: text.text.trim(),
                priority: priority,
                active: active,
                startAt: startAt,
                endAt: endAt,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

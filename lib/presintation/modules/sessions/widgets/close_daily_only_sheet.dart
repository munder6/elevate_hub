// lib/presintation/modules/sessions/widgets/close_daily_only_sheet.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../data/repositories/sessions_repo.dart';

class CloseDailyResult {
  final String paymentMethod;
  final num discount;
  final String? proofUrl;
  const CloseDailyResult({
    required this.paymentMethod,
    required this.discount,
    this.proofUrl,
  });
}

class CloseDailyOnlySheet extends StatefulWidget {
  final String sessionId;
  final num basePrice;
  final num drinksTotal;
  final num initialDiscount;
  final String initialPaymentMethod;
  final String? initialProofUrl;
  final SessionsRepo? sessionsRepo;

  const CloseDailyOnlySheet({
    super.key,
    required this.sessionId,
    required this.basePrice,
    required this.drinksTotal,
    this.initialDiscount = 0,
    this.initialPaymentMethod = 'cash',
    this.initialProofUrl,
    this.sessionsRepo,
  });

  @override
  State<CloseDailyOnlySheet> createState() => _CloseDailyOnlySheetState();
}

class _CloseDailyOnlySheetState extends State<CloseDailyOnlySheet> {
  final TextEditingController _discountCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late String _paymentMethod;
  String? _proofUrl;
  File? _localImage;
  bool _uploading = false;
  String? _uploadError;

  static const _methods = <({String value, String label})>[
    (value: 'cash', label: 'كاش'),
    (value: 'app', label: 'تطبيق'),
    (value: 'unpaid', label: 'غير مدفوع'),
    (value: 'card', label: 'بطاقة'),
    (value: 'other', label: 'أخرى'),
  ];

  SessionsRepo get _repo => widget.sessionsRepo ?? SessionsRepo();

  @override
  void initState() {
    super.initState();
    _paymentMethod =
    widget.initialPaymentMethod.isNotEmpty ? widget.initialPaymentMethod : 'cash';
    if (widget.initialDiscount > 0) {
      _discountCtrl.text = widget.initialDiscount.toString();
    }
    _proofUrl = widget.initialProofUrl;
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  num get _discount {
    final raw = _discountCtrl.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return 0;
    final parsed = num.tryParse(raw);
    if (parsed == null || parsed.isNaN) return 0;
    return parsed < 0 ? 0 : parsed;
  }

  num get _grandTotal {
    final total = widget.basePrice + widget.drinksTotal - _discount;
    return total < 0 ? 0 : total;
  }

  String? get _effectiveProof {
    final p = _proofUrl?.trim();
    if (p == null || p.isEmpty) return null;
    return p;
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _uploadError = null;
      _uploading = true;
    });
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) {
        if (mounted) setState(() => _uploading = false);
        return;
      }
      final file = File(picked.path);
      setState(() {
        _localImage = file;
      });
      final url = await _repo.uploadPaymentProof(
        sessionId: widget.sessionId,
        file: file,
      );
      if (!mounted) return;
      setState(() {
        _proofUrl = url;
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع إثبات الدفع')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadError = 'فشل الرفع: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفع الإثبات: $e')),
      );
    }
  }

  Future<void> _removeProof() async {
    if (_proofUrl != null && _proofUrl!.isNotEmpty) {
      try {
        await _repo.clearPaymentProof(widget.sessionId);
      } catch (_) {}
    }
    setState(() {
      _proofUrl = null;
      _localImage = null;
      _uploadError = null;
      _uploading = false;
    });
  }

  void _submit() {
    if (_paymentMethod == 'app' && _effectiveProof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إرفاق إثبات الدفع للتطبيق')),
      );
      return;
    }
    Navigator.pop(
      context,
      CloseDailyResult(
        paymentMethod: _paymentMethod,
        discount: _discount,
        proofUrl: _effectiveProof,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('إغلاق الاشتراك اليومي', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),

              // طريقة الدفع
              Text('طريقة الدفع', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _methods
                    .map(
                      (m) => ChoiceChip(
                    label: Text(m.label),
                    selected: _paymentMethod == m.value,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() => _paymentMethod = m.value);
                    },
                  ),
                )
                    .toList(),
              ),

              // إثبات الدفع للتطبيق
              if (_paymentMethod == 'app') ...[
                const SizedBox(height: 16),
                Text('إثبات الدفع', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (_uploadError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _uploadError!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading ? null : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('المعرض'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading ? null : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_rounded),
                        label: const Text('الكاميرا'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_uploading)
                  const Center(child: CircularProgressIndicator()),
                if (!_uploading && (_localImage != null || _proofUrl != null))
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _localImage != null
                              ? Image.file(_localImage!, fit: BoxFit.cover)
                              : Image.network(_proofUrl!, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.surface.withOpacity(.9),
                          ),
                          onPressed: _removeProof,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ],
                  ),
              ],

              const SizedBox(height: 16),
              // الخصم
              Text('الخصم', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  prefixText: '₪ ',
                  border: OutlineInputBorder(),
                  hintText: '0',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),
              // الملخص
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ملخص الفاتورة',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _summaryRow('سعر اليوم', _currency(widget.basePrice)),
                      _summaryRow('المشروبات/الخدمات', _currency(widget.drinksTotal)),
                      _summaryRow('الخصم', '- ${_currency(_discount)}'),
                      const Divider(),
                      _summaryRow('الإجمالي', _currency(_grandTotal), isStrong: true),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // الأزرار
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('تأكيد الإغلاق'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isStrong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: isStrong ? const TextStyle(fontWeight: FontWeight.w800) : null,
          ),
        ],
      ),
    );
  }

  String _currency(num value) => '₪${value.toStringAsFixed(2)}';
}

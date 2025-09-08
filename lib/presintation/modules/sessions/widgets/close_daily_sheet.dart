import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// غيّر المسار حسب مشروعك
import '../../../../data/repositories/sessions_repo.dart';

/// تنسيق الشيكل
String sCurrency(num v) => '₪ ${v.toStringAsFixed(2)}';

/// نتيجة الشيت: طريقة الدفع + الخصم
class CloseDailyResult {
  final String paymentMethod; // 'cash' | 'app' | 'unpaid' | 'card' | 'other'
  final num discount;         // الخصم المستخدم للإغلاق
  CloseDailyResult(this.paymentMethod, this.discount);
}

class CloseDailySheet extends StatefulWidget {
  final String sessionId; // ضروري
  final num minutes;
  final num hourlyRate;
  final num drinksTotal;
  final num discount; // الخصم الابتدائي المخزَّن (إن وجد)
  final SessionsRepo? sessionsRepo; // اختياري (بديل عن Provider)

  const CloseDailySheet({
    super.key,
    required this.sessionId,
    required this.minutes,
    required this.hourlyRate,
    required this.drinksTotal,
    this.discount = 0,
    this.sessionsRepo,
  });

  @override
  State<CloseDailySheet> createState() => _CloseDailySheetState();
}

class _CloseDailySheetState extends State<CloseDailySheet> {
  String _method = 'cash'; // الافتراضي
  bool _uploading = false;
  double? _progress; // 0..1 أثناء الرفع (شكلي)
  String? _proofUrl; // رابط التخزين بعد الرفع
  File? _localImage; // للمعاينة الفورية
  String? _uploadError;

  // خصم قابِل للتعديل
  late final TextEditingController _discountCtrl;
  num get _discount {
    final t = _discountCtrl.text.trim();
    if (t.isEmpty) return 0;
    return num.tryParse(t) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _discountCtrl = TextEditingController(text: widget.discount.toString());
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  SessionsRepo _resolveRepo(BuildContext context) {
    if (widget.sessionsRepo != null) return widget.sessionsRepo!;
    return context.read<SessionsRepo>();
  }

  Future<void> _pickImage({required ImageSource source}) async {
    setState(() => _uploadError = null);

    final picker = ImagePicker();
    final x = await picker.pickImage(source: source, imageQuality: 85);
    if (x == null) return;

    // معاينة محلية فورًا
    final f = File(x.path);
    setState(() {
      _localImage = f;
      _progress = 0.05;
      _uploading = true;
      _proofUrl = null; // إعادة تعيين لو كان في رابط قديم
    });

    // رفع للصندوق
    try {
      final repo = _resolveRepo(context);
      final url = await repo.uploadPaymentProof(
        sessionId: widget.sessionId,
        file: f,
      );

      if (!mounted) return;
      setState(() {
        _proofUrl = url;
        _uploading = false;
        _progress = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع إشعار الدفع ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _progress = null;
        _uploadError = 'فشل الرفع: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الرفع: $e')),
      );
    }
  }

  Future<void> _removeImage() async {
    final uploaded = _proofUrl != null && _proofUrl!.isNotEmpty;
    if (uploaded) {
      try {
        final repo = _resolveRepo(context);
        await repo.clearPaymentProof(widget.sessionId);
      } catch (_) {}
    }
    setState(() {
      _localImage = null;
      _proofUrl = null;
      _uploadError = null;
      _uploading = false;
      _progress = null;
    });
  }

  Widget _row(String label, String value, {bool isStrong = false}) {
    final style = isStrong
        ? const TextStyle(fontWeight: FontWeight.w800)
        : const TextStyle();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: style, textDirection: TextDirection.ltr),
        ],
      ),
    );
  }

  Widget _requireProofBanner(BuildContext context) {
    final needsProof =
        _method == 'app' && (_proofUrl == null || _proofUrl!.isEmpty);
    if (!needsProof) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: const ValueKey('proof-banner'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.error),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'الدفع عبر التطبيق يتطلّب إرفاق صورة إشعار الدفع.',
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentProofSection(BuildContext context) {
    if (_method != 'app') return const SizedBox.shrink();

    final hasLocal = _localImage != null;
    final hasUploaded = _proofUrl != null && _proofUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('إشعار الدفع (صورة):',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                _uploading ? null : () => _pickImage(source: ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('التقاط صورة'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                _uploading ? null : () => _pickImage(source: ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('من المعرض'),
              ),
            ),
          ],
        ),

        if (hasLocal) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_localImage!, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _uploading ? null : _removeImage,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  if (_uploading)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(value: _progress),
                    ),
                ],
              ),
            ),
          ),
          if (hasUploaded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: const [
                  Icon(Icons.verified_rounded, color: Colors.green, size: 18),
                  SizedBox(width: 6),
                  Text('تم رفع الصورة وربطها بالجلسة'),
                ],
              ),
            ),
          if (_uploadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_uploadError!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAmount = (widget.minutes / 60) * widget.hourlyRate;
    final liveGrand =
    (sessionAmount + widget.drinksTotal - _discount).toDouble();
    final maxDiscount = (sessionAmount + widget.drinksTotal).toDouble();
    final discountIsValid = _discount >= 0 && _discount <= maxDiscount;

    final mustAttachProof =
        _method == 'app' && (_proofUrl == null || _proofUrl!.isEmpty);
    final canConfirm = discountIsValid && !_uploading && !mustAttachProof;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // مقبض علوي صغير
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text('إغلاق جلسة اليوم',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),

                // شريط تنبيه لو لزم إثبات
                _requireProofBanner(context),

                // الملخّص
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _row('الدقائق', '${widget.minutes}'),
                        _row('الأجر بالساعة', sCurrency(widget.hourlyRate)),
                        _row('قيمة الجلسة', sCurrency(sessionAmount)),
                        const Divider(),
                        _row('المشروبات', sCurrency(widget.drinksTotal)),

                        // إدخال الخصم
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const Expanded(child: Text('الخصم')),
                              SizedBox(
                                width: 140,
                                child: TextField(
                                  controller: _discountCtrl,
                                  textDirection: TextDirection.ltr,
                                  keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: false),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]')),
                                  ],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    hintText: '0.00',
                                    prefixText: '₪ ',
                                    errorText:
                                    discountIsValid ? null : 'قيمة غير صالحة',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(),
                        _row('الإجمالي', sCurrency(liveGrand),
                            isStrong: true),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // اختيار طريقة الدفع
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('طريقة الدفع',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                const SizedBox(height: 6),

                RadioListTile<String>(
                  value: 'cash',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v!),
                  title: const Text('كاش'),
                ),
                RadioListTile<String>(
                  value: 'app',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v!),
                  title: const Text('تطبيق'),
                ),
                RadioListTile<String>(
                  value: 'card',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v!),
                  title: const Text('بطاقة'),
                ),
                RadioListTile<String>(
                  value: 'other',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v!),
                  title: const Text('أخرى'),
                ),
                RadioListTile<String>(
                  value: 'unpaid',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  groupValue: _method,
                  onChanged: (v) => setState(() => _method = v!),
                  title: const Text('لم يُدفع (تسجيل دين)'),
                ),

                // قسم إثبات الدفع (يظهر فقط عند اختيار "تطبيق")
                _paymentProofSection(context),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _uploading ? null : () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('تأكيد الإغلاق'),
                        onPressed: canConfirm
                            ? () {
                          Navigator.pop(
                              context, CloseDailyResult(_method, _discount));
                        }
                            : () {
                          if (!discountIsValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('تحقق من قيمة الخصم')),
                            );
                          } else if (_method == 'app' &&
                              (_proofUrl == null || _proofUrl!.isEmpty)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'الدفع عبر التطبيق يتطلّب إرفاق صورة إشعار الدفع')),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../data/models/app_settings.dart';

class AddOrderSheet extends StatefulWidget {
  final List<DrinkItem> drinks;
  const AddOrderSheet({super.key, required this.drinks});

  @override
  State<AddOrderSheet> createState() => _AddOrderSheetState();
}

// تنسيق العملة (شيكل)
String sCurrency(num v) => '₪ ${v.toStringAsFixed(2)}';

class _AddOrderSheetState extends State<AddOrderSheet> {
  int selected = 0;
  int qty = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeDrinks = widget.drinks.where((e) => e.active).toList();

    if (activeDrinks.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Icon(Icons.local_cafe_rounded,
                    color: theme.colorScheme.primary, size: 26),
                const SizedBox(height: 8),
                const Text('لا توجد مشروبات مفعّلة'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // تأمين الفهرس المختار إن تغيّر عدد المشروبات
    final sel = (selected >= 0 && selected < activeDrinks.length) ? selected : 0;
    final drink = activeDrinks[sel];
    final total = drink.price * qty;

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
            children: [
              // المقبض العلوي
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // العنوان
              Text('إضافة طلب', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),

              // اختيار المشروب
              DropdownButtonFormField<int>(
                value: sel,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'المشروب',
                  prefixIcon: Icon(Icons.local_cafe_rounded),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (int i = 0; i < activeDrinks.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${activeDrinks[i].name} — ${sCurrency(activeDrinks[i].price)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => selected = v ?? 0),
              ),
              const SizedBox(height: 10),

              // الكمية + الإجمالي
              Row(
                children: [
                  // عداد الكمية داخل كبسولة أنيقة
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surfaceVariant.withOpacity(.55),
                      border: Border.all(
                        color:
                        theme.colorScheme.outlineVariant.withOpacity(.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: qty > 1
                              ? () => setState(() => qty--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          tooltip: 'تنقيص',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '$qty',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => qty++),
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'زيادة',
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // الإجمالي
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.payments_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'الإجمالي: ${sCurrency(total)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // الأزرار
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop<Map<String, dynamic>>(context, {
                        'itemName': drink.name,
                        'unitPriceAtTime': drink.price,
                        'qty': qty,
                      });
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('إضافة'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

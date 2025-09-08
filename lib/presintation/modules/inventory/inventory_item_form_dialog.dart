import 'package:flutter/material.dart';
import '../../../data/models/inventory_item.dart';

class InventoryItemFormDialog extends StatefulWidget {
  final InventoryItem? initial;
  const InventoryItemFormDialog({super.key, this.initial});

  @override
  State<InventoryItemFormDialog> createState() => _InventoryItemFormDialogState();
}

class _InventoryItemFormDialogState extends State<InventoryItemFormDialog> {
  final _form = GlobalKey<FormState>();
  final name = TextEditingController();
  final sku = TextEditingController();
  final category = TextEditingController();
  final unit = TextEditingController(text: 'unit');
  final stock = TextEditingController(text: '0');
  final minStock = TextEditingController(text: '0');
  final costPrice = TextEditingController();
  final salePrice = TextEditingController();
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      name.text = i.name;
      sku.text = i.sku ?? '';
      category.text = i.category ?? '';
      unit.text = i.unit;
      stock.text = i.stock.toString();
      minStock.text = i.minStock.toString();
      costPrice.text = i.costPrice?.toString() ?? '';
      salePrice.text = i.salePrice?.toString() ?? '';
      isActive = i.isActive;
    }
  }

  @override
  void dispose() {
    name.dispose(); sku.dispose(); category.dispose(); unit.dispose();
    stock.dispose(); minStock.dispose(); costPrice.dispose(); salePrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add inventory item' : 'Edit inventory item'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v)=> (v==null||v.trim().isEmpty)?'Required':null),
              const SizedBox(height: 8),
              TextFormField(controller: sku, decoration: const InputDecoration(labelText: 'SKU (optional)')),
              const SizedBox(height: 8),
              TextFormField(controller: category, decoration: const InputDecoration(labelText: 'Category (optional)')),
              const SizedBox(height: 8),
              TextFormField(controller: unit, decoration: const InputDecoration(labelText: 'Unit'), validator: (v)=> (v==null||v.trim().isEmpty)?'Required':null),
              const SizedBox(height: 8),
              TextFormField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock'), validator: (v)=> num.tryParse(v??'')==null?'Number':null),
              const SizedBox(height: 8),
              TextFormField(controller: minStock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min stock'), validator: (v)=> num.tryParse(v??'')==null?'Number':null),
              const SizedBox(height: 8),
              TextFormField(controller: costPrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost price (optional)')),
              const SizedBox(height: 8),
              TextFormField(controller: salePrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sale price (optional)')),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Active'),
                value: isActive,
                onChanged: (v)=> setState(()=> isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: (){
            if (!(_form.currentState?.validate()??false)) return;
            final item = InventoryItem(
              id: widget.initial?.id ?? '',
              name: name.text.trim(),
              sku: sku.text.trim().isEmpty? null : sku.text.trim(),
              category: category.text.trim().isEmpty? null : category.text.trim(),
              unit: unit.text.trim(),
              stock: num.parse(stock.text),
              minStock: num.parse(minStock.text),
              costPrice: costPrice.text.trim().isEmpty? null : num.tryParse(costPrice.text.trim()),
              salePrice: salePrice.text.trim().isEmpty? null : num.tryParse(salePrice.text.trim()),
              isActive: isActive,
            );
            Navigator.pop<InventoryItem>(context, item);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class InventoryItem {
  final String id;
  final String name;
  final String? sku;
  final String? category;
  final String unit; // حبة/عبوة/كجم...
  final num stock;
  final num minStock;
  final num? costPrice;
  final num? salePrice;
  final bool isActive;

  InventoryItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.stock,
    required this.minStock,
    this.sku,
    this.category,
    this.costPrice,
    this.salePrice,
    this.isActive = true,
  });

  bool get isLow => stock < minStock;

  factory InventoryItem.fromMap(String id, Map<String, dynamic> m) => InventoryItem(
    id: id,
    name: (m['name'] ?? '').toString(),
    sku: m['sku']?.toString(),
    category: m['category']?.toString(),
    unit: (m['unit'] ?? '').toString(),
    stock: (m['stock'] ?? 0) as num,
    minStock: (m['minStock'] ?? 0) as num,
    costPrice: m['costPrice'] as num?,
    salePrice: m['salePrice'] as num?,
    isActive: (m['isActive'] ?? true) as bool,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    if (sku != null) 'sku': sku,
    if (category != null) 'category': category,
    'unit': unit,
    'stock': stock,
    'minStock': minStock,
    if (costPrice != null) 'costPrice': costPrice,
    if (salePrice != null) 'salePrice': salePrice,
    'isActive': isActive,
  };

  InventoryItem copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    String? unit,
    num? stock,
    num? minStock,
    num? costPrice,
    num? salePrice,
    bool? isActive,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      costPrice: costPrice ?? this.costPrice,
      salePrice: salePrice ?? this.salePrice,
      isActive: isActive ?? this.isActive,
    );
  }
}

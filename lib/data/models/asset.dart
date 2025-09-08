class AssetModel {
  final String id;
  final String name;
  final String? category;
  final DateTime? purchaseDate;
  final num value;
  final String? notes;
  final bool active;

  AssetModel({
    required this.id,
    required this.name,
    required this.value,
    this.category,
    this.purchaseDate,
    this.notes,
    this.active = true,
  });

  factory AssetModel.fromMap(String id, Map<String, dynamic> m) => AssetModel(
    id: id,
    name: (m['name'] ?? '').toString(),
    category: m['category']?.toString(),
    purchaseDate: m['purchaseDate'] != null
        ? DateTime.tryParse(m['purchaseDate'].toString())
        : null,
    value: (m['value'] ?? 0) as num,
    notes: m['notes']?.toString(),
    active: (m['active'] ?? true) as bool,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    if (category != null && category!.trim().isNotEmpty) 'category': category,
    if (purchaseDate != null) 'purchaseDate': purchaseDate!.toIso8601String(),
    'value': value,
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
    'active': active,
  };

  AssetModel copyWith({
    String? id,
    String? name,
    String? category,
    DateTime? purchaseDate,
    num? value,
    String? notes,
    bool? active,
  }) {
    return AssetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      value: value ?? this.value,
      notes: notes ?? this.notes,
      active: active ?? this.active,
    );
  }
}

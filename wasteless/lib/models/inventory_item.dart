import 'category.dart';

class InventoryItem {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime expiryDate;
  final int quantity;
  final int reminderDaysBefore;
  final int reminderHoursBefore;
  final String? fridgeId;
  final List<Category> categories;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.expiryDate,
    required this.quantity,
    this.reminderDaysBefore = 1,
    this.reminderHoursBefore = 0,
    this.fridgeId,
    this.categories = const [],
  });

  bool get isExpired => expiryDate.isBefore(DateTime.now());

  bool get isExpiringSoon {
    final now = DateTime.now();
    if (isExpired) return false;
    final diff = expiryDate.difference(now);
    return diff.inDays <= 2;
  }

  Duration get timeUntilExpiry => expiryDate.difference(DateTime.now());

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    // Parse categories from nested join if present
    final List<Category> parsedCategories = [];
    final rawCats = map['inventory_item_categories'];
    if (rawCats is List) {
      for (final catEntry in rawCats) {
        if (catEntry is Map) {
          final catData = catEntry['categories'];
          if (catData is Map<String, dynamic>) {
            parsedCategories.add(Category.fromMap(catData));
          } else if (catData is Map) {
            parsedCategories.add(Category.fromMap(Map<String, dynamic>.from(catData)));
          }
        }
      }
    }

    final createdAtStr = map['created_at']?.toString();
    final expiryDateStr = map['expiry_date']?.toString();

    return InventoryItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now(),
      expiryDate: expiryDateStr != null ? DateTime.tryParse(expiryDateStr) ?? DateTime.now() : DateTime.now(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      reminderDaysBefore: (map['reminder_days_before'] as num?)?.toInt() ?? 1,
      reminderHoursBefore: (map['reminder_hours_before'] as num?)?.toInt() ?? 0,
      fridgeId: map['fridge_id']?.toString(),
      categories: parsedCategories,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
    'expiry_date': expiryDate.toIso8601String(),
    'quantity': quantity,
    'reminder_days_before': reminderDaysBefore,
    'reminder_hours_before': reminderHoursBefore,
    if (fridgeId != null) 'fridge_id': fridgeId,
    'inventory_item_categories': categories.map((c) => {
      'category_id': c.id,
      'categories': c.toMap(),
    }).toList(),
  };

  InventoryItem copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? expiryDate,
    int? quantity,
    int? reminderDaysBefore,
    int? reminderHoursBefore,
    String? fridgeId,
    List<Category>? categories,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      expiryDate: expiryDate ?? this.expiryDate,
      quantity: quantity ?? this.quantity,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      reminderHoursBefore: reminderHoursBefore ?? this.reminderHoursBefore,
      fridgeId: fridgeId ?? this.fridgeId,
      categories: categories ?? this.categories,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'InventoryItem(id: $id, name: $name, qty: $quantity)';
}

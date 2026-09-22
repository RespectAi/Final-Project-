class Category {
  final String id;
  final String name;
  final String? iconUrl;
  final int? defaultExpiryDays;

  const Category({
    required this.id,
    required this.name,
    this.iconUrl,
    this.defaultExpiryDays,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      iconUrl: map['icon_url']?.toString(),
      defaultExpiryDays: map['default_expiry_days'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (iconUrl != null) 'icon_url': iconUrl,
    if (defaultExpiryDays != null) 'default_expiry_days': defaultExpiryDays,
  };

  Category copyWith({
    String? id,
    String? name,
    String? iconUrl,
    int? defaultExpiryDays,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconUrl: iconUrl ?? this.iconUrl,
      defaultExpiryDays: defaultExpiryDays ?? this.defaultExpiryDays,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Category(id: $id, name: $name)';
}

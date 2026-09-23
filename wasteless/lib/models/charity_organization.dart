// lib/models/charity_organization.dart

class CharityOrganization {
  final String id;
  final String name;
  final String category; // 'Orphanage', 'Food Bank', 'NGO', 'Shelter'
  final String phone;
  final String? whatsapp;
  final String? email;
  final String address;
  final String city;
  final List<String> acceptedItems;
  final String operatingHours;
  final bool isVerified;
  final DateTime? createdAt;

  const CharityOrganization({
    required this.id,
    required this.name,
    required this.category,
    required this.phone,
    this.whatsapp,
    this.email,
    required this.address,
    this.city = 'Lagos',
    this.acceptedItems = const [],
    this.operatingHours = 'Mon-Sat: 8:00 AM - 5:00 PM',
    this.isVerified = true,
    this.createdAt,
  });

  factory CharityOrganization.fromMap(Map<String, dynamic> map) {
    List<String> items = [];
    if (map['accepted_items'] is List) {
      items = (map['accepted_items'] as List).map((e) => e.toString()).toList();
    }

    final createdAtStr = map['created_at']?.toString();

    return CharityOrganization(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Charity Organization',
      category: map['category']?.toString() ?? 'NGO',
      phone: map['phone']?.toString() ?? '',
      whatsapp: map['whatsapp']?.toString() ?? map['phone']?.toString(),
      email: map['email']?.toString(),
      address: map['address']?.toString() ?? '',
      city: map['city']?.toString() ?? 'Lagos',
      acceptedItems: items,
      operatingHours: map['operating_hours']?.toString() ?? 'Mon-Sat: 8:00 AM - 5:00 PM',
      isVerified: map['is_verified'] == true || map['is_verified'] == 1,
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'phone': phone,
    if (whatsapp != null) 'whatsapp': whatsapp,
    if (email != null) 'email': email,
    'address': address,
    'city': city,
    'accepted_items': acceptedItems,
    'operating_hours': operatingHours,
    'is_verified': isVerified,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  /// Fallback verified charities accessible even completely offline
  static const List<CharityOrganization> defaultCharities = [
    CharityOrganization(
      id: 'c1-little-saints',
      name: 'Little Saints Orphanage',
      category: 'Orphanage',
      phone: '+2348033024825',
      whatsapp: '+2348033024825',
      email: 'info@littlesaintsorphanage.org',
      address: '6/8 D\'Alberto Street, Palmgrove Estate',
      city: 'Lagos',
      acceptedItems: ['Baby Food', 'Grains', 'Fresh Produce', 'Dairy', 'Snacks', 'Canned Food'],
      operatingHours: 'Mon-Sat: 8:00 AM - 6:00 PM',
      isVerified: true,
    ),
    CharityOrganization(
      id: 'c2-lagos-foodbank',
      name: 'Lagos Food Bank Initiative (LFBI)',
      category: 'Food Bank',
      phone: '+2347012920202',
      whatsapp: '+2347012920202',
      email: 'contact@lagosfoodbank.org',
      address: 'Plot 14/16 Raw Materials Lane, Off Oshodi-Apapa Exp.',
      city: 'Lagos',
      acceptedItems: ['Grains', 'Canned Food', 'Bakery', 'Vegetables', 'Packaged Meals'],
      operatingHours: 'Mon-Fri: 8:30 AM - 5:00 PM',
      isVerified: true,
    ),
    CharityOrganization(
      id: 'c3-hearts-of-gold',
      name: 'Hearts of Gold Children\'s Hospice',
      category: 'Shelter',
      phone: '+2348033086968',
      whatsapp: '+2348033086968',
      email: 'heartsofgoldhospice@yahoo.com',
      address: 'Plot 75, Alhaji Masha Road, Surulere',
      city: 'Lagos',
      acceptedItems: ['Baby Formula', 'Fresh Fruits', 'Cereal', 'Cooked Meals', 'Supplements'],
      operatingHours: 'Daily: 8:00 AM - 6:00 PM',
      isVerified: true,
    ),
    CharityOrganization(
      id: 'c4-red-cross',
      name: 'Red Cross Community Relief Hub',
      category: 'NGO',
      phone: '+2348035002233',
      whatsapp: '+2348035002233',
      email: 'relief@redcrossnigeria.org',
      address: '11 Eko Akete Close, Off St. Gregory College Rd, Obalende',
      city: 'Lagos',
      acceptedItems: ['Canned Food', 'Rice & Grains', 'Packaged Water', 'Emergency Meals'],
      operatingHours: 'Mon-Sat: 8:00 AM - 5:00 PM',
      isVerified: true,
    ),
    CharityOrganization(
      id: 'c5-child-lifeline',
      name: 'Child Life-Line Foundation',
      category: 'Orphanage',
      phone: '+2348023157790',
      whatsapp: '+2348023157790',
      email: 'info@childlifeline.org',
      address: 'Gbagada Phase 2, Beside Comprehensive High School',
      city: 'Lagos',
      acceptedItems: ['Bread & Bakery', 'Cooked Meals', 'Juice & Beverages', 'Fresh Meat/Fish'],
      operatingHours: 'Daily: 7:30 AM - 7:00 PM',
      isVerified: true,
    ),
  ];
}

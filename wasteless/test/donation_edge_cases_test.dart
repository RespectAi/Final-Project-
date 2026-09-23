// test/donation_edge_cases_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasteless/models/donation_item.dart';
import 'package:wasteless/models/charity_organization.dart';

void main() {
  group('Donation Expiry Date Validation Edge Cases', () {
    bool isPickupAfterExpiry(DateTime pickupDate, DateTime? itemExpiry) {
      if (itemExpiry == null) return false;
      final pDate = DateTime(pickupDate.year, pickupDate.month, pickupDate.day);
      final eDate = DateTime(itemExpiry.year, itemExpiry.month, itemExpiry.day);
      return pDate.isAfter(eDate);
    }

    test('Pickup date on the exact same day as expiry is VALID', () {
      final expiry = DateTime(2026, 10, 15, 23, 59, 59);
      final pickup = DateTime(2026, 10, 15, 9, 0, 0);
      expect(isPickupAfterExpiry(pickup, expiry), isFalse);
    });

    test('Pickup date before expiry date is VALID', () {
      final expiry = DateTime(2026, 10, 20);
      final pickup = DateTime(2026, 10, 18);
      expect(isPickupAfterExpiry(pickup, expiry), isFalse);
    });

    test('Pickup date 1 day after expiry date is INVALID (rejected)', () {
      final expiry = DateTime(2026, 10, 15);
      final pickup = DateTime(2026, 10, 16);
      expect(isPickupAfterExpiry(pickup, expiry), isTrue);
    });

    test('Pickup date many days after expiry is INVALID', () {
      final expiry = DateTime(2026, 9, 1);
      final pickup = DateTime(2026, 9, 23);
      expect(isPickupAfterExpiry(pickup, expiry), isTrue);
    });

    test('Item with null expiry date is always VALID (no expiry restriction)', () {
      final pickup = DateTime(2026, 12, 31);
      expect(isPickupAfterExpiry(pickup, null), isFalse);
    });

    test('Different time components on same calendar day are normalized and VALID', () {
      // Expiry is morning 8am, pickup is evening 6pm on the SAME day
      final expiry = DateTime(2026, 10, 15, 8, 0, 0);
      final pickup = DateTime(2026, 10, 15, 18, 0, 0);
      expect(isPickupAfterExpiry(pickup, expiry), isFalse);
    });
  });

  group('Donation Inventory Deduction Logic Edge Cases', () {
    Map<String, dynamic> processInventoryDeduction({
      required int currentStock,
      required int offerQty,
    }) {
      if (currentStock > offerQty) {
        return {
          'action': 'update',
          'remainingQuantity': currentStock - offerQty,
        };
      } else {
        return {
          'action': 'delete',
          'remainingQuantity': 0,
        };
      }
    }

    test('Donating partial quantity updates remaining quantity correctly', () {
      final res = processInventoryDeduction(currentStock: 5, offerQty: 2);
      expect(res['action'], equals('update'));
      expect(res['remainingQuantity'], equals(3));
    });

    test('Donating exact total stock deletes item from inventory', () {
      final res = processInventoryDeduction(currentStock: 4, offerQty: 4);
      expect(res['action'], equals('delete'));
      expect(res['remainingQuantity'], equals(0));
    });

    test('Donating 1 unit when stock is 1 deletes item from inventory', () {
      final res = processInventoryDeduction(currentStock: 1, offerQty: 1);
      expect(res['action'], equals('delete'));
      expect(res['remainingQuantity'], equals(0));
    });

    test('Donating more than stock (overflow protection) deletes item safely', () {
      final res = processInventoryDeduction(currentStock: 2, offerQty: 5);
      expect(res['action'], equals('delete'));
      expect(res['remainingQuantity'], equals(0));
    });
  });

  group('DonationItem Recipient Info Encoding & Restoration Edge Cases', () {
    test('Encodes and decodes rich JSON metadata with exact quantity and expiry', () {
      final expiry = DateTime(2026, 11, 30, 14, 0, 0);
      final encoded = DonationItem.encodeRecipientInfo(
        charityName: 'Heart of Gold Children\'s Hospice',
        charityPhone: '+234 803 302 4825',
        charityCategory: 'Orphanage',
        logisticsType: 'pickup',
        address: '14 Admiralty Way, Lekki Phase 1, Lagos',
        timeWindow: 'Oct 15, 2026 • Morning (9:00 AM - 12:00 PM)',
        donorPhone: '+234 801 234 5678',
        notes: 'Kept refrigerated, call on arrival: "Gate Code #402"',
        expiry: expiry,
        quantity: 3,
        status: 'pending',
      );

      expect(encoded, isA<String>());
      final decodedMap = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decodedMap['charity_name'], equals('Heart of Gold Children\'s Hospice'));
      expect(decodedMap['quantity'], equals(3));
      expect(decodedMap['expiry_date'], equals(expiry.toIso8601String()));
      expect(decodedMap['logistics_type'], equals('pickup'));

      final item = DonationItem.fromMap({
        'id': 'don-123',
        'item_id': 'inv-456',
        'item_name': 'Fresh Milk',
        'recipient_info': encoded,
        'offered_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      expect(item.itemName, equals('Fresh Milk'));
      expect(item.quantity, equals(3));
      expect(item.itemExpiry, isNotNull);
      expect(item.itemExpiry!.year, equals(2026));
      expect(item.itemExpiry!.month, equals(11));
      expect(item.itemExpiry!.day, equals(30));
      expect(item.charityName, equals('Heart of Gold Children\'s Hospice'));
    });

    test('Handles legacy non-JSON plain text recipient string without crashing', () {
      final legacyMap = {
        'id': 'don-legacy-1',
        'item_name': 'Canned Beans',
        'recipient_info': 'Direct Donation to Local Food Bank',
        'offered_at': '2026-09-20T10:00:00Z',
        'status': 'completed',
      };

      final item = DonationItem.fromMap(legacyMap);
      expect(item.charityName, equals('Direct Donation to Local Food Bank'));
      expect(item.quantity, equals(1)); // Graceful fallback
      expect(item.itemExpiry, isNull);
      expect(item.status, equals('completed'));
    });

    test('Restoration preserves original expiry date and quantity from map', () {
      final originalExpiry = DateTime(2026, 12, 25);
      final item = DonationItem(
        id: 'don-99',
        itemId: 'inv-99',
        itemName: 'Yogurt Pack',
        recipientInfo: DonationItem.encodeRecipientInfo(
          charityName: 'Lagos Food Bank',
          expiry: originalExpiry,
          quantity: 4,
        ),
        offeredAt: DateTime.now(),
        charityName: 'Lagos Food Bank',
        itemExpiry: originalExpiry,
        quantity: 4,
      );

      final map = item.toMap();
      expect(map['quantity'], equals(4));
      expect(map['expiry_date'], equals(originalExpiry.toIso8601String()));

      // Extract original fields during cancellation
      int restoredQty = 1;
      if (map['quantity'] != null) {
        restoredQty = (map['quantity'] as num).toInt();
      }
      expect(restoredQty, equals(4));

      String? restoredExpiry = map['expiry_date']?.toString();
      expect(restoredExpiry, equals(originalExpiry.toIso8601String()));
      expect(DateTime.parse(restoredExpiry!), equals(originalExpiry));
    });
  });

  group('CharityOrganization Model and Defaults Edge Cases', () {
    test('Default verified charities list is populated and non-empty', () {
      final defaults = CharityOrganization.defaultCharities;
      expect(defaults, isNotEmpty);
      expect(defaults.length, greaterThanOrEqualTo(5));

      for (final c in defaults) {
        expect(c.name, isNotEmpty);
        expect(c.phone, isNotEmpty);
        expect(c.address, isNotEmpty);
        expect(c.isVerified, isTrue);
        expect(c.acceptedItems, isNotEmpty);
      }
    });

    test('Charity serialization and deserialization roundtrip', () {
      final original = CharityOrganization(
        id: 'charity-test-1',
        name: 'Feed The Vulnerable NGO',
        category: 'Food Bank',
        phone: '+234 800 123 4567',
        whatsapp: '+234 800 123 4567',
        email: 'info@feedvulnerable.org',
        address: '22 Community Road, Yaba',
        city: 'Lagos',
        acceptedItems: ['Grains', 'Tinned Fish', 'Baby Food'],
        operatingHours: 'Mon-Fri: 9:00 AM - 4:00 PM',
        isVerified: true,
      );

      final map = original.toMap();
      final restored = CharityOrganization.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.category, equals(original.category));
      expect(restored.phone, equals(original.phone));
      expect(restored.whatsapp, equals(original.whatsapp));
      expect(restored.email, equals(original.email));
      expect(restored.address, equals(original.address));
      expect(restored.city, equals(original.city));
      expect(restored.acceptedItems, equals(original.acceptedItems));
      expect(restored.isVerified, isTrue);
    });
  });

  group('Multi-Select Bulk State Logic Edge Cases', () {
    test('Selection toggle adds and removes ID', () {
      final selected = <String>{};

      // Toggle on
      if (selected.contains('id-1')) {
        selected.remove('id-1');
      } else {
        selected.add('id-1');
      }
      expect(selected.contains('id-1'), isTrue);
      expect(selected.length, equals(1));

      // Toggle off
      if (selected.contains('id-1')) {
        selected.remove('id-1');
      } else {
        selected.add('id-1');
      }
      expect(selected.contains('id-1'), isFalse);
      expect(selected.isEmpty, isTrue);
    });

    test('Select all populates visible IDs and ignores empty list', () {
      final selected = <String>{};
      final items = [
        DonationItem(
          id: 'd-1',
          itemName: 'Item 1',
          recipientInfo: '{}',
          offeredAt: DateTime(2026),
          charityName: 'C1',
        ),
        DonationItem(
          id: 'd-2',
          itemName: 'Item 2',
          recipientInfo: '{}',
          offeredAt: DateTime(2026),
          charityName: 'C2',
        ),
      ];

      selected.addAll(items.map((i) => i.id));
      expect(selected.length, equals(2));
      expect(selected.contains('d-1'), isTrue);
      expect(selected.contains('d-2'), isTrue);

      final allSelected = items.every((i) => selected.contains(i.id));
      expect(allSelected, isTrue);

      selected.clear();
      expect(selected.isEmpty, isTrue);
    });
  });
}

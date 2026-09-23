// lib/services/communication_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/common.dart';

class CommunicationService {
  CommunicationService._();

  /// Clean phone numbers into international digits-only format
  static String normalizePhone(String rawPhone) {
    // Keep '+' if present at the start, strip spaces, dashes, brackets
    String cleaned = rawPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      // Common Nigerian local number format (e.g. 0803... -> +234803...)
      cleaned = '+234${cleaned.substring(1)}';
    }
    return cleaned;
  }

  /// Format a structured, professional WhatsApp donation dispatch message
  static String formatDonationWhatsAppMessage({
    required String itemName,
    int quantity = 1,
    DateTime? expiry,
    required String charityName,
    required String logisticsType, // 'pickup' or 'drop_off'
    String? address,
    String? timeWindow,
    String? donorPhone,
    String? notes,
  }) {
    final dateFormat = DateFormat.yMMMd();
    final expiryStr = expiry != null ? dateFormat.format(expiry) : 'Fresh / Packaged';
    final isPickup = logisticsType.toLowerCase() == 'pickup';

    final buffer = StringBuffer();
    buffer.writeln('🍱 *FOOD DONATION OFFER — WasteLess App*');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Hello *$charityName*, a food donor has offered a donation for your organization:');
    buffer.writeln();
    buffer.writeln('📦 *Item:* $quantity x $itemName');
    buffer.writeln('⏳ *Expiry / Shelf Life:* $expiryStr');
    buffer.writeln('🚚 *Logistics:* ${isPickup ? "Requesting Home Pickup" : "Donor Will Drop Off"}');
    if (address != null && address.isNotEmpty) {
      buffer.writeln('📍 *${isPickup ? "Pickup Address" : "Destination"}:* $address');
    }
    if (timeWindow != null && timeWindow.isNotEmpty) {
      buffer.writeln('🕒 *Available Time Window:* $timeWindow');
    }
    if (donorPhone != null && donorPhone.isNotEmpty) {
      buffer.writeln('📞 *Donor Phone:* $donorPhone');
    }
    if (notes != null && notes.isNotEmpty) {
      buffer.writeln('📝 *Notes:* $notes');
    }
    buffer.writeln();
    buffer.writeln('----------------------------------------');
    buffer.writeln('_Please reply to this message to coordinate pickup or delivery._');

    return buffer.toString();
  }

  /// Launch WhatsApp with pre-filled message and recipient phone number
  static Future<bool> launchWhatsApp({
    required BuildContext context,
    required String phone,
    required String message,
  }) async {
    final cleanPhone = normalizePhone(phone).replaceAll('+', '');
    final encodedMessage = Uri.encodeComponent(message);

    // 1. Try native WhatsApp scheme
    final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage');
    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}

    // 2. Try Universal wa.me web link
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');
    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}

    // 3. Fallback: Copy message to clipboard
    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      showCornerToast(
        context,
        message: 'Could not open WhatsApp. Message copied to clipboard!',
      );
    }
    return false;
  }

  /// Direct phone call dialer
  static Future<bool> launchCall({
    required BuildContext context,
    required String phone,
  }) async {
    final cleanPhone = normalizePhone(phone);
    final telUri = Uri.parse('tel:$cleanPhone');

    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}

    // Fallback: Copy phone to clipboard
    await Clipboard.setData(ClipboardData(text: cleanPhone));
    if (context.mounted) {
      showCornerToast(
        context,
        message: 'Phone number $cleanPhone copied to clipboard',
      );
    }
    return false;
  }

  /// Send email
  static Future<bool> launchEmail({
    required BuildContext context,
    required String email,
    required String subject,
    required String body,
  }) async {
    final mailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      if (await canLaunchUrl(mailUri)) {
        await launchUrl(mailUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: body));
    if (context.mounted) {
      showCornerToast(context, message: 'Email draft copied to clipboard');
    }
    return false;
  }
}

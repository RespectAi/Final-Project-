import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class DonationPage extends StatefulWidget {
  static const route = '/donate';
  final SupabaseService supa;
  const DonationPage({required this.supa, Key? key}) : super(key: key);

  @override
  _DonationPageState createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  final _controller = TextEditingController();

  Future<void> _submit(String itemId) async {
    if (_controller.text.trim().isEmpty) return;
    await widget.supa.offerDonation(itemId, _controller.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final itemId = ModalRoute.of(context)!.settings.arguments as String;
    return Scaffold(
      appBar: AppBar(title: Text('Offer Donation')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Recipient Info'),
            ),
            Spacer(),
            ElevatedButton(onPressed: () => _submit(itemId), child: Text('Donate'))
          ],
        ),
      ),
    );
}
}

import 'package:flutter/material.dart';
import 'package:skipit/core/theme/app_colors.dart';
import 'package:skipit/core/widgets/skipit_widgets.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final List<Map<String, dynamic>> _mockCards = [
    {
      'id': '1',
      'number': '•••• •••• •••• 4242',
      'expiry': '12/28',
      'holder': 'MRIDUL',
      'brand': 'Visa',
      'gradient': [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
      'isDefault': true,
    },
    {
      'id': '2',
      'number': '•••• •••• •••• 8899',
      'expiry': '08/30',
      'holder': 'MRIDUL',
      'brand': 'Mastercard',
      'gradient': [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
      'isDefault': false,
    }
  ];

  final List<Map<String, dynamic>> _mockPayouts = [
    {
      'id': '1',
      'type': 'UPI',
      'identifier': 'mridul@oksbi',
      'isDefault': true,
    },
    {
      'id': '2',
      'type': 'Bank Account',
      'identifier': 'HDFC Bank •••• 5678',
      'isDefault': false,
    }
  ];

  void _showAddCardModal() {
    final numberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final holderController = TextEditingController(text: 'MRIDUL');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Add New Card',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SkipItTextField(
                    controller: numberController,
                    label: 'Card Number',
                    hint: '1234 5678 1234 5678',
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.replaceAll(' ', '').length != 16 ? 'Invalid card number' : null,
                  ),
                  const SizedBox(height: 16),
                  SkipItTextField(
                    controller: holderController,
                    label: 'Cardholder Name',
                    hint: 'e.g. Mridul',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SkipItTextField(
                          controller: expiryController,
                          label: 'Expiry Date',
                          hint: 'MM/YY',
                          keyboardType: TextInputType.datetime,
                          validator: (v) => v!.length != 5 ? 'Invalid' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SkipItTextField(
                          controller: cvvController,
                          label: 'CVV',
                          hint: '123',
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.length != 3 ? 'Invalid' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SkipItButton(
                    label: 'Save Card',
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final rawNum = numberController.text.trim();
                        final maskedNum = '•••• •••• •••• ${rawNum.substring(rawNum.length - 4)}';
                        
                        setState(() {
                          _mockCards.add({
                            'id': DateTime.now().millisecondsSinceEpoch.toString(),
                            'number': maskedNum,
                            'expiry': expiryController.text.trim(),
                            'holder': holderController.text.trim().toUpperCase(),
                            'brand': rawNum.startsWith('4') ? 'Visa' : 'Mastercard',
                            'gradient': [const Color(0xFF8A2387), const Color(0xFFE94057)],
                            'isDefault': false,
                          });
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Card added successfully!', style: TextStyle(color: AppColors.white)),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddPayoutModal() {
    final upiController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Link UPI Payout',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SkipItTextField(
                    controller: upiController,
                    label: 'UPI ID',
                    hint: 'username@bank',
                    validator: (v) => !v!.contains('@') ? 'Invalid UPI ID' : null,
                  ),
                  const SizedBox(height: 32),
                  SkipItButton(
                    label: 'Link UPI ID',
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        setState(() {
                          _mockPayouts.add({
                            'id': DateTime.now().millisecondsSinceEpoch.toString(),
                            'type': 'UPI',
                            'identifier': upiController.text.trim().toLowerCase(),
                            'isDefault': false,
                          });
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payout account linked!', style: TextStyle(color: AppColors.white)),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setDefaultCard(String id) {
    setState(() {
      for (var card in _mockCards) {
        card['isDefault'] = card['id'] == id;
      }
    });
  }

  void _setDefaultPayout(String id) {
    setState(() {
      for (var p in _mockPayouts) {
        p['isDefault'] = p['id'] == id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment Methods', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saved Cards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(
                  onPressed: _showAddCardModal,
                  icon: const Icon(Icons.add, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _mockCards.length,
                itemBuilder: (context, index) {
                  final card = _mockCards[index];
                  return _buildCreditCard(card);
                },
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payout Accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(
                  onPressed: _showAddPayoutModal,
                  icon: const Icon(Icons.add, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._mockPayouts.map((payout) => _buildPayoutRow(payout)),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: AppColors.success, size: 24),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PCI-DSS Secure Storage', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 4),
                        Text('Your card credentials are encrypted with bank-level encryption standards.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCard(Map<String, dynamic> card) {
    return GestureDetector(
      onTap: () => _setDefaultCard(card['id']),
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: card['gradient'],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (card['gradient'][0] as Color).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
          border: card['isDefault']
              ? Border.all(color: AppColors.white, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.nfc, color: AppColors.white, size: 28),
                Text(
                  card['brand'],
                  style: const TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              card['number'],
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CARDHOLDER', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9)),
                    const SizedBox(height: 4),
                    Text(card['holder'], style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EXPIRES', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9)),
                    const SizedBox(height: 4),
                    Text(card['expiry'], style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (card['isDefault'])
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('DEFAULT', style: TextStyle(color: AppColors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutRow(Map<String, dynamic> payout) {
    return GestureDetector(
      onTap: () => _setDefaultPayout(payout['id']),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: payout['isDefault'] ? AppColors.primary : Colors.transparent,
            width: payout['isDefault'] ? 1.5 : 0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                payout['type'] == 'UPI' ? Icons.account_balance_wallet_outlined : Icons.account_balance,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payout['type'],
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    payout['identifier'],
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (payout['isDefault'])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('DEFAULT PAYOUT', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}

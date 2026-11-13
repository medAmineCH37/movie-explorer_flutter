import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/subscription.dart';

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    super.key,
    required this.plan,
    this.processingTime = const Duration(milliseconds: 1200),
  });

  final SubscriptionPlan plan;
  final Duration processingTime;

  static Future<String?> show(BuildContext context, SubscriptionPlan plan) =>
      showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PaymentDialog(plan: plan),
      );

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _isPaying = false;

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) =>
      (value ?? '').trim().length < 3 ? 'Enter the name on the card' : null;

  String? _validateNumber(String? value) =>
      (value ?? '').length != 16 ? 'Card number must have 16 digits' : null;

  String? _validateExpiry(String? value) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(value ?? '');
    if (match == null) return 'Use MM/YY';
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    if (month < 1 || month > 12) return 'Invalid month';
    final now = DateTime.now();
    if (DateTime(year, month + 1).isBefore(DateTime(now.year, now.month + 1))) {
      return 'Card has expired';
    }
    return null;
  }

  String? _validateCvv(String? value) =>
      (value ?? '').length != 3 ? '3 digits' : null;

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isPaying = true);
    await Future<void>.delayed(widget.processingTime);
    if (!mounted) return;
    final number = _numberController.text;
    Navigator.of(context).pop(number.substring(number.length - 4));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Payment'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.workspace_premium),
                    title: Text(widget.plan.label),
                    trailing: Text(
                      widget.plan.priceLabel,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isPaying,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name on card',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _numberController,
                  enabled: !_isPaying,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Card number',
                    hintText: '4242424242424242',
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  validator: _validateNumber,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expiryController,
                        enabled: !_isPaying,
                        keyboardType: TextInputType.datetime,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                          LengthLimitingTextInputFormatter(5),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Expiry',
                          hintText: 'MM/YY',
                        ),
                        validator: _validateExpiry,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cvvController,
                        enabled: !_isPaying,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: const InputDecoration(labelText: 'CVV'),
                        validator: _validateCvv,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Demo payment: no money is charged.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isPaying ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isPaying ? null : _pay,
          child: _isPaying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Pay ${widget.plan.price.toStringAsFixed(2)} TND'),
        ),
      ],
    );
  }
}

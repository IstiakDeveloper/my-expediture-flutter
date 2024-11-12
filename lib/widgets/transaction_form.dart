import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TransactionForm extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> paymentMethods;
  final Function({
    required String type,
    required double amount,
    required String paymentMethodId,
    String? categoryId,
    String? description,
  }) onSubmit;

  const TransactionForm({
    super.key,
    required this.categories,
    required this.paymentMethods,
    required this.onSubmit,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType = 'expense';
  String? _selectedCategoryId;
  String? _selectedPaymentMethodId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.paymentMethods.isNotEmpty) {
      _selectedPaymentMethodId = widget.paymentMethods.first['id'].toString();
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await widget.onSubmit(
        type: _selectedType,
        amount: double.parse(_amountController.text),
        paymentMethodId: _selectedPaymentMethodId!,
        categoryId: _selectedCategoryId,
        description: _descriptionController.text.trim(),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Transaction',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Transaction Type Selector
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'expense',
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: 'income',
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                  _selectedCategoryId = null; // Reset category when type changes
                });
              },
            ),
            const SizedBox(height: 16),

            // Payment Method Dropdown
            DropdownButtonFormField<String>(
              value: _selectedPaymentMethodId,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              items: widget.paymentMethods.map((method) {
                return DropdownMenuItem(
                  value: method['id'].toString(),
                  child: Text(method['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethodId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a payment method';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('No Category'),
                ),
                ...widget.categories
                    .where((cat) => cat['type'] == _selectedType)
                    .map((category) {
                  return DropdownMenuItem(
                    value: category['id'].toString(),
                    child: Text(category['name']),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Amount TextField
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null) {
                  return 'Please enter a valid amount';
                }
                if (amount <= 0) {
                  return 'Amount must be greater than zero';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description TextField
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Submit Button
            FilledButton.icon(
              onPressed: _isProcessing ? null : _submitForm,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isProcessing ? 'Adding...' : 'Add Transaction'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
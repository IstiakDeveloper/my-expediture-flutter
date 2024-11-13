import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../data/datasources/local/database_helper.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _uuid = const Uuid();
  final _currencyFormat = NumberFormat("#,##0.00", "en_US");

  String? _selectedCategoryId;
  String? _selectedPaymentMethodId;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _incomeTransactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load only income categories
      final allCategories = await _dbHelper.getAllCategories();
      final incomeCategories =
          allCategories.where((cat) => cat['type'] == 'income').toList();

      final paymentMethods = await _dbHelper.getAllPaymentMethods();
      final transactions = await _dbHelper
          .getIncomeTransactions(); // You'll need to add this method

      setState(() {
        _categories = incomeCategories;
        _paymentMethods = paymentMethods;
        _incomeTransactions = transactions;

        if (_selectedPaymentMethodId == null && paymentMethods.isNotEmpty) {
          _selectedPaymentMethodId = paymentMethods.first['id'].toString();
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addIncome() async {
    // Clear any existing error messages
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Validate amount
    if (_amountController.text.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    double? amount;
    try {
      amount = double.parse(_amountController.text);
      if (amount <= 0) {
        _showError('Amount must be greater than 0');
        return;
      }
    } catch (e) {
      _showError('Please enter a valid amount');
      return;
    }

    // Validate payment method
    if (_selectedPaymentMethodId == null) {
      _showError('Please select a payment method');
      return;
    }

    // Validate category for better organization
    if (_selectedCategoryId == null) {
      _showError('Please select a category');
      return;
    }

    // Show loading indicator
    setState(() => _isLoading = true);

    try {
      print('\n=== Starting Income Transaction ===');
      print('Amount: $amount');
      print('Payment Method: $_selectedPaymentMethodId');
      print('Category: $_selectedCategoryId');
      print('Description: ${_descriptionController.text}');

      // Generate unique ID for transaction
      final String transactionId = _uuid.v4();

      // Insert the transaction
      await _dbHelper.insertTransaction(
        id: transactionId,
        type: 'income', // Always 'income' for this screen
        amount: amount,
        paymentMethodId: _selectedPaymentMethodId!,
        categoryId: _selectedCategoryId,
        description: _descriptionController.text.trim(),
      );

      // Verify transaction was stored
      final bool transactionExists =
          await _dbHelper.verifyTransaction(transactionId);
      print(
          'Transaction verification: ${transactionExists ? 'Success' : 'Failed'}');

      if (!transactionExists) {
        throw Exception('Transaction failed to save');
      }

      // Clear form
      _clearForm();

      // Reload data to show new transaction
      await _loadData();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                    'Income of ৳${_currencyFormat.format(amount)} added successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      print('Income transaction completed successfully');
    } catch (e, stackTrace) {
      print('Error adding income:');
      print(e);
      print('Stack trace:');
      print(stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to add income: ${e.toString()}',
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // Hide loading indicator
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

// Helper method to clear form
  void _clearForm() {
    setState(() {
      _amountController.clear();
      _descriptionController.clear();
      _selectedCategoryId = null;
    });
  }

// Helper method to show error messages
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

// Add this method for better debug logging
  Future<void> _logDatabaseState() async {
    print('\n=== Current Database State ===');
    try {
      // Get all transactions
      final transactions = await _dbHelper.getAllTransactions();
      print('\nTransactions:');
      for (var transaction in transactions) {
        print('ID: ${transaction['id']}');
        print('Type: ${transaction['type']}');
        print('Amount: ${transaction['amount']}');
        print('Category: ${transaction['category_name']}');
        print('Payment Method: ${transaction['payment_method_name']}');
        print('Date: ${transaction['date']}');
        print('---');
      }

      // Get all payment method balances
      final balances = await _dbHelper.getAllBalances();
      print('\nPayment Method Balances:');
      balances.forEach((method, balance) {
        print('$method: $balance');
      });

      print('\n===========================\n');
    } catch (e) {
      print('Error logging database state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Add Income',
          style: TextStyle(color: Colors.green),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Income Entry Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Amount Field
                          TextField(
                            controller: _amountController,
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              prefixIcon: const Icon(Icons.attach_money,
                                  color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Category Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedCategoryId,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              prefixIcon: const Icon(Icons.category,
                                  color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem(
                                value: category['id'].toString(),
                                child: Text(category['name']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedCategoryId = value);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Payment Method Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedPaymentMethodId,
                            decoration: InputDecoration(
                              labelText: 'Payment Method',
                              prefixIcon: const Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _paymentMethods.map((method) {
                              return DropdownMenuItem(
                                value: method['id'].toString(),
                                child: Text(method['name']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedPaymentMethodId = value);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Description Field
                          TextField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description (Optional)',
                              prefixIcon:
                                  const Icon(Icons.note, color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Add Button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _addIncome,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.add),
                              label:
                                  Text(_isLoading ? 'Adding...' : 'Add Income'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recent Incomes List
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Recent Income',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (_incomeTransactions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text('No income transactions yet'),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _incomeTransactions.length,
                            itemBuilder: (context, index) {
                              final transaction = _incomeTransactions[index];
                              final amount = transaction['amount'] as double;
                              final date = DateTime.parse(transaction['date']);

                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.green,
                                  child: Icon(Icons.arrow_upward,
                                      color: Colors.white),
                                ),
                                title: Text(
                                  '৳${_currencyFormat.format(amount)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(transaction['category_name'] ??
                                        'No Category'),
                                    if (transaction['description']
                                            ?.isNotEmpty ??
                                        false)
                                      Text(
                                        transaction['description'],
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  DateFormat('MMM dd, yyyy').format(date),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
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

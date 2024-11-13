import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../data/datasources/local/database_helper.dart';

class TransactionsScreen extends StatefulWidget {
  final String? initialType;
  const TransactionsScreen({super.key, this.initialType});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _isLoading = false;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _uuid = const Uuid();
  final _currencyFormat = NumberFormat("#,##0.00", "en_US");

  String _selectedType = 'expense';
  String? _selectedCategoryId;
  String? _selectedPaymentMethodId;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _transactions = [];
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? 'expense';
    _loadData();
  }

  Future<void> _loadData() async {
    final categories = await _dbHelper.getAllCategories();
    final paymentMethods = await _dbHelper.getAllPaymentMethods();
    final transactions = await _dbHelper.getAllTransactions();

    setState(() {
      _categories = categories;
      _paymentMethods = paymentMethods;
      _transactions = transactions;

      if (_selectedPaymentMethodId == null && paymentMethods.isNotEmpty) {
        _selectedPaymentMethodId = paymentMethods.first['id'].toString();
      }
    });
  }

  Future<void> _addTransaction() async {
    // Form validation
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate amount is a number and greater than 0
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate payment method is selected
    if (_selectedPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment method'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Category validation for expense transactions
    if (_selectedType == 'expense' && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category for expense'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      print('Adding transaction with following details:');
      print('Amount: $amount');
      print('Type: $_selectedType');
      print('Payment Method: $_selectedPaymentMethodId');
      print('Category: $_selectedCategoryId');
      print('Description: ${_descriptionController.text}');

      // Insert transaction
      final result = await _dbHelper.insertTransaction(
        id: _uuid.v4(),
        type: _selectedType,
        amount: amount,
        paymentMethodId: _selectedPaymentMethodId!,
        categoryId: _selectedCategoryId,
        description: _descriptionController.text.trim(),
      );

      print('Transaction insert result: $result');

      // Clear form
      _amountController.clear();
      _descriptionController.clear();
      setState(() {
        _showForm = false;
        _selectedCategoryId = null;
      });

      // Reload data
      await _loadData();

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text('Transaction added successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error adding transaction: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error adding transaction: ${e.toString()}',
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) return 'No Category';
    final category = _categories.firstWhere(
      (cat) => cat['id'].toString() == categoryId,
      orElse: () => {'name': 'Unknown'},
    );
    return category['name'].toString();
  }

  IconData _getIconForCategory(String? categoryId) {
    if (categoryId == null) return Icons.category;
    final category = _categories.firstWhere(
      (cat) => cat['id'].toString() == categoryId,
      orElse: () => {'icon': 'default'},
    );

    switch (category['icon']) {
      case 'money':
        return Icons.attach_money;
      case 'food':
        return Icons.restaurant;
      case 'car':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Transactions',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showForm ? Icons.close : Icons.add,
              color: Colors.black87,
            ),
            onPressed: () {
              setState(() => _showForm = !_showForm);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Add Transaction Form
          if (_showForm)
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Transaction Type
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'expense',
                          icon: Icon(Icons.remove_circle_outline),
                          label: Text('Expense'),
                        ),
                        ButtonSegment(
                          value: 'income',
                          icon: Icon(Icons.add_circle_outline),
                          label: Text('Income'),
                        ),
                      ],
                      selected: {_selectedType},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _selectedType = newSelection.first;
                          _selectedCategoryId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Payment Method
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMethodId,
                      decoration: InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.account_balance_wallet),
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

                    // Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.category),
                      ),
                      items: _categories
                          .where((cat) => cat['type'] == _selectedType)
                          .map((category) {
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

                    // Amount
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.money),
                        errorText: _amountController.text.isNotEmpty &&
                                double.tryParse(_amountController.text) == null
                            ? 'Please enter a valid amount'
                            : null,
                      ),
                      onChanged: (value) {
                        // Force rebuild to show/hide error text
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Add Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _addTransaction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedType == 'income'
                              ? Colors.green
                              : Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Add ${_selectedType.capitalize()} Transaction',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Transactions List
          Expanded(
            child: _transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _transactions[index];
                      final isIncome = transaction['type'] == 'income';
                      final amount = transaction['amount'] as double;
                      final date = DateTime.parse(transaction['date']);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            child: Icon(
                              _getIconForCategory(transaction['category_id']),
                              color: isIncome ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                '৳${_currencyFormat.format(amount)}',
                                style: TextStyle(
                                  color: isIncome ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('MMM dd').format(date),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getCategoryName(transaction['category_id']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (transaction['description']?.isNotEmpty ??
                                  false)
                                Text(
                                  transaction['description'],
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                          trailing: Text(
                            transaction['payment_method_name'] ?? 'Unknown',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: !_showForm
          ? FloatingActionButton(
              onPressed: () => setState(() => _showForm = true),
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

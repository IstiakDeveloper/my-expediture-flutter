// lib/screens/expense_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../data/datasources/local/database_helper.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _uuid = const Uuid();
  final _currencyFormat = NumberFormat("#,##0.00", "en_US");

  String? _selectedCategoryId;
  String? _selectedPaymentMethodId;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _expenseTransactions = [];
  bool _isLoading = false;
  double _totalExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load only expense categories
      final allCategories = await _dbHelper.getAllCategories();
      final expenseCategories =
          allCategories.where((cat) => cat['type'] == 'expense').toList();

      final paymentMethods = await _dbHelper.getAllPaymentMethods();
      final transactions = await _dbHelper
          .getExpenseTransactions(); // Add this method to DatabaseHelper

      // Calculate total expenses
      double total = 0.0;
      for (var transaction in transactions) {
        total += transaction['amount'] as double;
      }

      setState(() {
        _categories = expenseCategories;
        _paymentMethods = paymentMethods;
        _expenseTransactions = transactions;
        _totalExpenses = total;

        if (_selectedPaymentMethodId == null && paymentMethods.isNotEmpty) {
          _selectedPaymentMethodId = paymentMethods.first['id'].toString();
        }
      });
    } catch (e) {
      print('Error loading data: $e');
      _showError('Failed to load expense data');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addExpense() async {
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

    // Validate category
    if (_selectedCategoryId == null) {
      _showError('Please select a category');
      return;
    }

    // Check payment method balance
    try {
      final balances = await _dbHelper.getAllBalances();
      final selectedMethodBalance = balances[_paymentMethods.firstWhere(
          (method) => method['id'] == _selectedPaymentMethodId)['name']];

      final currentBalance = selectedMethodBalance ?? 0.0;
      if (currentBalance < amount) {
        _showError('Insufficient balance in selected payment method');
        return;
      }
    } catch (e) {
      print('Error checking balance: $e');
      _showError('Failed to verify balance');
      return;
    }

    // Show loading indicator
    setState(() => _isLoading = true);

    try {
      print('\n=== Starting Expense Transaction ===');
      print('Amount: $amount');
      print('Payment Method: $_selectedPaymentMethodId');
      print('Category: $_selectedCategoryId');
      print('Description: ${_descriptionController.text}');

      // Generate unique ID for transaction
      final String transactionId = _uuid.v4();

      // Insert the transaction
      await _dbHelper.insertTransaction(
        id: transactionId,
        type: 'expense',
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
                    'Expense of ৳${_currencyFormat.format(amount)} added successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      print('Expense transaction completed successfully');
    } catch (e, stackTrace) {
      print('Error adding expense:');
      print(e);
      print('Stack trace:');
      print(stackTrace);

      if (mounted) {
        _showError('Failed to add expense: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    setState(() {
      _amountController.clear();
      _descriptionController.clear();
      _selectedCategoryId = null;
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Add Expense',
          style: TextStyle(color: Colors.red),
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
                  // Total Expenses Card
                  Card(
                    elevation: 4,
                    color: Colors.red[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Total Expenses',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '৳${_currencyFormat.format(_totalExpenses)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Expense Entry Card
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
                              labelStyle: TextStyle(color: Colors.red[700]),
                              prefixIcon: Icon(Icons.attach_money,
                                  color: Colors.red[700]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.red[700]!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Category Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedCategoryId,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              labelStyle: TextStyle(color: Colors.red[700]),
                              prefixIcon:
                                  Icon(Icons.category, color: Colors.red[700]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.red[700]!),
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
                              labelStyle: TextStyle(color: Colors.red[700]),
                              prefixIcon: Icon(Icons.account_balance_wallet,
                                  color: Colors.red[700]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.red[700]!),
                              ),
                            ),
                            items: _paymentMethods.map((method) {
                              double balance = 0.0;
                              try {
                                balance =
                                    double.parse(method['balance'].toString());
                              } catch (e) {
                                print('Error parsing balance: $e');
                              }
                              return DropdownMenuItem(
                                value: method['id'].toString(),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(method['name']),
                                    Text(
                                      '৳${_currencyFormat.format(balance)}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
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
                              labelStyle: TextStyle(color: Colors.red[700]),
                              prefixIcon:
                                  Icon(Icons.note, color: Colors.red[700]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.red[700]!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Add Button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _addExpense,
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
                              label: Text(
                                  _isLoading ? 'Adding...' : 'Add Expense'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
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

                  // Recent Expenses List
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
                            'Recent Expenses',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (_expenseTransactions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text('No expense transactions yet'),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _expenseTransactions.length,
                            itemBuilder: (context, index) {
                              final transaction = _expenseTransactions[index];
                              final amount = transaction['amount'] as double;
                              final date = DateTime.parse(transaction['date']);

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red[50],
                                  child: Icon(
                                    Icons.arrow_downward,
                                    color: Colors.red[700],
                                  ),
                                ),
                                title: Text(
                                  '৳${_currencyFormat.format(amount)}',
                                  style: TextStyle(
                                    color: Colors.red[700],
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
                                    Text(
                                      transaction['payment_method_name'] ??
                                          'Unknown',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
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

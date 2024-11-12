import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../data/datasources/local/database_helper.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();
  final _currencyFormat = NumberFormat("#,##0.00", "en_US");
  
  // Controllers for loan form
  final _personNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();
  
  // Controllers for payment form
  final _paymentAmountController = TextEditingController();
  final _paymentDescriptionController = TextEditingController();

  String _selectedType = 'given'; // 'given' or 'taken'
  String? _selectedPaymentMethodId;
  DateTime? _selectedDueDate;
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _loans = [];
  bool _showForm = false;
  double _totalGiven = 0.0;
  double _totalTaken = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final paymentMethods = await _dbHelper.getAllPaymentMethods();
    final loans = await _dbHelper.getPendingLoans();

    double givenAmount = 0.0;
    double takenAmount = 0.0;
    for (var loan in loans) {
      if (loan['type'] == 'given') {
        givenAmount += loan['remaining_amount'] as double;
      } else {
        takenAmount += loan['remaining_amount'] as double;
      }
    }

    setState(() {
      _paymentMethods = paymentMethods;
      _loans = loans;
      _totalGiven = givenAmount;
      _totalTaken = takenAmount;
      
      if (_selectedPaymentMethodId == null && paymentMethods.isNotEmpty) {
        _selectedPaymentMethodId = paymentMethods.first['id'].toString();
      }
    });
  }

  Future<void> _addLoan() async {
    if (_personNameController.text.isEmpty || 
        _amountController.text.isEmpty || 
        _selectedPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      final amount = double.parse(_amountController.text);
      await _dbHelper.insertLoan(
        id: _uuid.v4(),
        personName: _personNameController.text,
        amount: amount,
        type: _selectedType,
        paymentMethodId: _selectedPaymentMethodId!,
        description: _descriptionController.text,
        dueDate: _selectedDueDate,
      );

      _clearLoanForm();
      setState(() => _showForm = false);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding loan: $e')),
        );
      }
    }
  }

  Future<void> _addPayment(String loanId) async {
    if (_paymentAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter payment amount')),
      );
      return;
    }

    try {
      final amount = double.parse(_paymentAmountController.text);
      await _dbHelper.insertLoanPayment(
        id: _uuid.v4(),
        loanId: loanId,
        amount: amount,
        paymentMethodId: _selectedPaymentMethodId!,
        description: _paymentDescriptionController.text,
      );

      _clearPaymentForm();
      await _loadData();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding payment: $e')),
        );
      }
    }
  }

  void _clearLoanForm() {
    _personNameController.clear();
    _amountController.clear();
    _descriptionController.clear();
    _dueDateController.clear();
    setState(() => _selectedDueDate = null);
  }

  void _clearPaymentForm() {
    _paymentAmountController.clear();
    _paymentDescriptionController.clear();
  }

  void _showAddPaymentDialog(Map<String, dynamic> loan) {
    final remainingAmount = loan['remaining_amount'] as double;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Payment', style: Theme.of(context).textTheme.titleLarge),
            Text(
              loan['person_name'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Remaining Amount Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Remaining:'),
                  Text(
                    '₹${_currencyFormat.format(remainingAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment Amount
            TextField(
              controller: _paymentAmountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Description
            TextField(
              controller: _paymentDescriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.description),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => _addPayment(loan['id']),
            icon: const Icon(Icons.check),
            label: const Text('Add Payment'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Loans',
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
          // Summary Cards
          if (!_showForm)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Given Loans Card
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green[100]!,
                              Colors.green[50]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'To Receive',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${_currencyFormat.format(_totalGiven)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Taken Loans Card
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red[100]!,
                              Colors.red[50]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'To Pay',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${_currencyFormat.format(_totalTaken)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Loan Form
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
                    // Loan Type
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'given',
                          icon: Icon(Icons.arrow_upward),
                          label: Text('Given'),
                        ),
                        ButtonSegment(
                          value: 'taken',
                          icon: Icon(Icons.arrow_downward),
                          label: Text('Taken'),
                        ),
                      ],
                      selected: {_selectedType},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() => _selectedType = newSelection.first);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Person Name
                    TextField(
                      controller: _personNameController,
                      decoration: InputDecoration(
                        labelText: 'Person Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.money),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Due Date
                    TextField(
                      controller: _dueDateController,
                      readOnly: true,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDueDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDueDate = picked;
                            _dueDateController.text = 
                                DateFormat('MMM dd, yyyy').format(picked);
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Due Date (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
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
                      child: FilledButton.icon(
                        onPressed: _addLoan,
                        icon: const Icon(Icons.add),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: Text(
                          'Add ${_selectedType.toUpperCase()} Loan',
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

          // Loans List
          Expanded(
            child: _loans.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.money_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No active loans',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _loans.length,
                    itemBuilder: (context, index) {
                      final loan = _loans[index];
                      final isGiven = loan['type'] == 'given';
                      final amount = loan['amount'] as double;
                      final paidAmount = loan['paid_amount'] as double;
                      final remainingAmount = loan['remaining_amount'] as double;
                      final date = DateTime.parse(loan['date']);
                      final dueDate = loan['due_date'] != null 
                          ? DateTime.parse(loan['due_date'])
                          : null;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: isGiven
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            child: Icon(
                              isGiven ? Icons.arrow_upward : Icons.arrow_downward,
                              color: isGiven ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            loan['person_name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${_currencyFormat.format(remainingAmount)} remaining',
                                style: TextStyle(
                                  color: isGiven ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (dueDate != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Due: ${DateFormat('MMM dd, yyyy').format(dueDate)}',
                                  style: TextStyle(
                                    color: dueDate.isBefore(DateTime.now())
                                        ? Colors.red
                                        : Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: TextButton.icon(
                            onPressed: () => _showAddPaymentDialog(loan),
                            icon: const Icon(Icons.add),
                            label: const Text('Payment'),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLoanDetail(
                                    'Total Amount',
                                    '₹${_currencyFormat.format(amount)}',
                                  ),
                                  _buildLoanDetail(
                                    'Paid Amount',
                                    '₹${_currencyFormat.format(paidAmount)}',
                                  ),
                                  _buildLoanDetail(
                                    'Date',
                                    DateFormat('MMM dd, yyyy').format(date),
                                  ),
                                  if (loan['description']?.isNotEmpty ?? false)
                                    _buildLoanDetail(
                                      'Description',
                                      loan['description'],
                                    ),
                                ],
                              ),
                            ),
                          ],
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

  Widget _buildLoanDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    _paymentAmountController.dispose();
    _paymentDescriptionController.dispose();
    super.dispose();
  }
}
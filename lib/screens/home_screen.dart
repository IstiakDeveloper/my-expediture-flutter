// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/datasources/local/database_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _currencyFormat = NumberFormat("#,##0.00", "en_US");

  bool _isLoading = false;
  double _totalBalance = 0.0;
  Map<String, double> _balances = {};
  List<Map<String, dynamic>> _recentTransactions = [];
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final balances = await _dbHelper.getAllBalances();
      final totalBalance = await _dbHelper.getTotalBalance();
      final recentTransactions =
          await _dbHelper.getRecentTransactions(limit: 5);

      // Calculate totals
      double incomeTotal = 0.0;
      double expenseTotal = 0.0;
      for (var transaction in recentTransactions) {
        if (transaction['type'] == 'income') {
          incomeTotal += transaction['amount'] as double;
        } else {
          expenseTotal += transaction['amount'] as double;
        }
      }

      setState(() {
        _balances = balances;
        _totalBalance = totalBalance;
        _recentTransactions = recentTransactions;
        _totalIncome = incomeTotal;
        _totalExpense = expenseTotal;
      });
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading data')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Total Balance Card
                    Card(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[700]!, Colors.blue[500]!],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Total Balance',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '৳${_currencyFormat.format(_totalBalance)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            title: 'Income',
                            icon: Icons.arrow_upward,
                            color: Colors.green,
                            amount: _totalIncome,
                            onTap: () => Navigator.pushNamed(context, '/income')
                                .then((_) => _loadData()),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuickActionCard(
                            title: 'Expense',
                            icon: Icons.arrow_downward,
                            color: Colors.red,
                            amount: _totalExpense,
                            onTap: () =>
                                Navigator.pushNamed(context, '/expense')
                                    .then((_) => _loadData()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Payment Methods
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Payment Methods',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _balances.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final methodName =
                                  _balances.keys.elementAt(index);
                              final balance = _balances[methodName] ?? 0.0;
                              return ListTile(
                                leading: Icon(
                                  _getPaymentMethodIcon(methodName),
                                  color: _getPaymentMethodColor(methodName),
                                ),
                                title: Text(methodName),
                                trailing: Text(
                                  '৳${_currencyFormat.format(balance)}',
                                  style: TextStyle(
                                    color: balance >= 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Recent Transactions
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Recent Transactions',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    '/transactions',
                                  ).then((_) => _loadData()),
                                  child: const Text('See All'),
                                ),
                              ],
                            ),
                          ),
                          if (_recentTransactions.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text('No recent transactions'),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recentTransactions.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final transaction = _recentTransactions[index];
                                final isIncome =
                                    transaction['type'] == 'income';
                                final amount = transaction['amount'] as double;
                                final date =
                                    DateTime.parse(transaction['date']);

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isIncome
                                        ? Colors.green[50]
                                        : Colors.red[50],
                                    child: Icon(
                                      isIncome
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      color:
                                          isIncome ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  title: Text(
                                    '৳${_currencyFormat.format(amount)}',
                                    style: TextStyle(
                                      color:
                                          isIncome ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        transaction['category_name'] ??
                                            'No Category',
                                      ),
                                      Text(
                                        DateFormat('MMM dd, yyyy').format(date),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.pushNamed(context, '/loans').then((_) => _loadData()),
        child: const Icon(Icons.money),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required double amount,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '৳${_currencyFormat.format(amount)}',
                style: TextStyle(
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPaymentMethodIcon(String methodName) {
    switch (methodName.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'bank 1':
      case 'bank 2':
        return Icons.account_balance;
      case 'bkash':
      case 'nagad':
        return Icons.phone_android;
      default:
        return Icons.account_balance_wallet;
    }
  }

  Color _getPaymentMethodColor(String methodName) {
    switch (methodName.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'bank 1':
        return Colors.blue;
      case 'bank 2':
        return Colors.purple;
      case 'bkash':
        return Colors.pink;
      case 'nagad':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }
}

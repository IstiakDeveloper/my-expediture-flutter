import 'package:flutter/material.dart';
import '../data/datasources/local/database_helper.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, double> _balances = {};
  double _totalBalance = 0.0;
  final currencyFormat = NumberFormat("#,##0.00", "en_US");

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    final balances = await _dbHelper.getAllBalances();
    final totalBalance = await _dbHelper.getTotalBalance();
    setState(() {
      _balances = balances;
      _totalBalance = totalBalance;
    });
  }

  IconData _getIconForMethod(String methodName) {
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

  Color _getColorForMethod(String methodName) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Finance Overview',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadBalances,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBalances,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Total Balance Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1A237E),
                          Color(0xFF3949AB),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(24.0),
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
                          '₹${currencyFormat.format(_totalBalance)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildQuickAction(
                              icon: Icons.add_circle_outline,
                              label: 'Income',
                              color: Colors.green[300]!,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/transactions',
                                  arguments: 'income',
                                ).then((_) => _loadBalances());
                              },
                            ),
                            _buildQuickAction(
                              icon: Icons.remove_circle_outline,
                              label: 'Expense',
                              color: Colors.red[300]!,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/transactions',
                                  arguments: 'expense',
                                ).then((_) => _loadBalances());
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Payment Methods Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Payment Methods',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),

              // Payment Methods Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _balances.length,
                  itemBuilder: (context, index) {
                    String methodName = _balances.keys.elementAt(index);
                    double balance = _balances[methodName] ?? 0.0;
                    Color methodColor = _getColorForMethod(methodName);
                    
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              methodColor.withOpacity(0.1),
                              methodColor.withOpacity(0.05),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getIconForMethod(methodName),
                              color: methodColor,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              methodName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${currencyFormat.format(balance)}',
                              style: TextStyle(
                                color: methodColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Quick Actions
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context: context,
                        icon: Icons.account_balance_wallet,
                        label: 'Transactions',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/transactions')
                              .then((_) => _loadBalances());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context: context,
                        icon: Icons.money,
                        label: 'Loans',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/loans')
                              .then((_) => _loadBalances());
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
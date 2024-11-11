import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../widgets/expense_list.dart';
import '../widgets/expense_summary.dart';
import '../screens/add_expense_screen.dart';  // Add this import

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Expense> _expenses = [];

  void _addExpense(Expense expense) {
    setState(() {
      _expenses.add(expense);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expense Tracker'),
      ),
      body: Column(
        children: [
          ExpenseSummary(expenses: _expenses),
          Expanded(
            child: ExpenseList(expenses: _expenses),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(onAdd: _addExpense),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
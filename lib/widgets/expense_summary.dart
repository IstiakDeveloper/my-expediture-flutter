import 'package:flutter/material.dart';
import '../models/expense.dart';

class ExpenseSummary extends StatelessWidget {
  final List<Expense> expenses;

  ExpenseSummary({required this.expenses});

  double get totalExpenses {
    return expenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(15),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Expenses:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '\$${totalExpenses.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
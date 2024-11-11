import 'package:flutter/material.dart';
import '../models/expense.dart';

class ExpenseList extends StatelessWidget {
  final List<Expense> expenses;

  ExpenseList({required this.expenses});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: expenses.length,
      itemBuilder: (ctx, index) {
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          child: ListTile(
            leading: CircleAvatar(
              child: Text('\$'),
            ),
            title: Text(expenses[index].title),
            subtitle: Text(
              '${expenses[index].category} - ${expenses[index].date.toString().split(' ')[0]}',
            ),
            trailing: Text(
              '\$${expenses[index].amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import '../models/expense.dart';

class AddExpenseScreen extends StatefulWidget {
  final Function(Expense) onAdd;

  AddExpenseScreen({required this.onAdd});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();

  void _submitExpense() {
    if (_titleController.text.isEmpty || _amountController.text.isEmpty) {
      return;
    }

    final newExpense = Expense(
      id: DateTime.now().toString(),
      title: _titleController.text,
      amount: double.parse(_amountController.text),
      date: _selectedDate,
      category: _selectedCategory,
    );

    widget.onAdd(newExpense);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Expense'),
      ),
      body: Card(
        margin: EdgeInsets.all(15),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              DropdownButtonFormField(
                value: _selectedCategory,
                items: ['Food', 'Transport', 'Utilities', 'Entertainment', 'Others']
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value.toString();
                  });
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitExpense,
                child: Text('Add Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
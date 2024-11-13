import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'expenditure.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here if needed
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create payment methods table
    await db.execute('''
      CREATE TABLE payment_methods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL DEFAULT 0.0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create transactions table with payment method
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id TEXT,
        payment_method_id TEXT,
        description TEXT,
        date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES categories (id),
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id)
      )
    ''');

    // Create loans table with enhanced tracking
    await db.execute('''
      CREATE TABLE loans (
        id TEXT PRIMARY KEY,
        person_name TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        payment_method_id TEXT,
        description TEXT,
        due_date TIMESTAMP,
        date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id)
      )
    ''');

    // Create loan payments table to track partial payments
    await db.execute('''
      CREATE TABLE loan_payments (
        id TEXT PRIMARY KEY,
        loan_id TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_method_id TEXT,
        date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        description TEXT,
        FOREIGN KEY (loan_id) REFERENCES loans (id),
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id)
      )
    ''');

    await _insertDefaultData(db);
  }

  Future<void> _insertDefaultData(Database db) async {
    // Insert default payment methods
    List<Map<String, dynamic>> defaultPaymentMethods = [
      {'id': '1', 'name': 'Cash', 'type': 'cash', 'balance': 0.0},
      {'id': '2', 'name': 'Bank 1', 'type': 'bank', 'balance': 0.0},
      {'id': '3', 'name': 'Bank 2', 'type': 'bank', 'balance': 0.0},
      {'id': '4', 'name': 'bKash', 'type': 'mobile', 'balance': 0.0},
      {'id': '5', 'name': 'Nagad', 'type': 'mobile', 'balance': 0.0},
    ];

    // Insert default categories
    List<Map<String, dynamic>> defaultCategories = [
      {'id': '1', 'name': 'Salary', 'type': 'income', 'icon': 'money'},
      {'id': '2', 'name': 'Food', 'type': 'expense', 'icon': 'food'},
      {'id': '3', 'name': 'Transport', 'type': 'expense', 'icon': 'car'},
      {'id': '4', 'name': 'Shopping', 'type': 'expense', 'icon': 'shopping'},
    ];

    Batch batch = db.batch();
    for (var method in defaultPaymentMethods) {
      batch.insert('payment_methods', method);
    }
    for (var category in defaultCategories) {
      batch.insert('categories', category);
    }
    await batch.commit();
  }

  // Payment Methods Methods
  Future<List<Map<String, dynamic>>> getAllPaymentMethods() async {
    Database db = await database;
    return await db.query('payment_methods');
  }

  Future<void> updatePaymentMethodBalance(
      String methodId, double amount, String type) async {
    Database db = await database;

    try {
      print('Updating payment method balance separately...');
      print('Method ID: $methodId');
      print('Amount: $amount');
      print('Type: $type');

      // Get current balance
      final List<Map<String, dynamic>> result = await db.query(
        'payment_methods',
        columns: ['balance'],
        where: 'id = ?',
        whereArgs: [methodId],
      );

      if (result.isEmpty) {
        throw Exception('Payment method not found');
      }

      double currentBalance = result.first['balance'] as double;
      print('Current balance: $currentBalance');

      double newBalance =
          type == 'income' ? currentBalance + amount : currentBalance - amount;

      print('New balance: $newBalance');

      // Update balance
      int updateResult = await db.update(
        'payment_methods',
        {'balance': newBalance},
        where: 'id = ?',
        whereArgs: [methodId],
      );

      print('Update result: $updateResult');

      if (updateResult != 1) {
        throw Exception('Failed to update payment method balance');
      }
    } catch (e, stackTrace) {
      print('Error updating balance: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to update balance: $e');
    }
  }

  // Categories Methods
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    Database db = await database;
    return await db.query('categories');
  }

  Future<int> insertTransaction({
    required String id,
    required String type,
    required double amount,
    required String paymentMethodId,
    String? categoryId,
    String? description,
  }) async {
    Database db = await database;

    try {
      print('Starting database transaction...');
      print('Input Data:');
      print('ID: $id');
      print('Type: $type');
      print('Amount: $amount');
      print('Payment Method ID: $paymentMethodId');
      print('Category ID: $categoryId');
      print('Description: $description');

      // Begin transaction
      int result = await db.transaction((txn) async {
        print('Inserting transaction record...');

        // Create transaction map
        final Map<String, dynamic> transactionData = {
          'id': id,
          'type': type,
          'amount': amount,
          'payment_method_id': paymentMethodId,
          'category_id': categoryId,
          'description': description,
          'date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        };

        print('Transaction data: $transactionData');

        // Insert the transaction
        int insertId = await txn.insert(
          'transactions',
          transactionData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        print('Transaction inserted with ID: $insertId');

        // Verify the transaction was inserted
        final List<Map<String, dynamic>> check = await txn.query(
          'transactions',
          where: 'id = ?',
          whereArgs: [id],
        );

        if (check.isEmpty) {
          throw Exception('Transaction was not inserted properly');
        }

        print('Updating payment method balance...');
        // Get current balance
        final List<Map<String, dynamic>> currentBalance = await txn.query(
          'payment_methods',
          columns: ['balance'],
          where: 'id = ?',
          whereArgs: [paymentMethodId],
        );

        if (currentBalance.isEmpty) {
          throw Exception('Payment method not found');
        }

        double balance = currentBalance.first['balance'] as double;
        double newBalance =
            type == 'income' ? balance + amount : balance - amount;

        print('Old balance: $balance');
        print('New balance: $newBalance');

        // Update payment method balance
        int updateResult = await txn.update(
          'payment_methods',
          {'balance': newBalance},
          where: 'id = ?',
          whereArgs: [paymentMethodId],
        );

        print('Balance update result: $updateResult');

        if (updateResult != 1) {
          throw Exception('Failed to update payment method balance');
        }

        return insertId;
      });

      print('Transaction completed successfully with result: $result');
      return result;
    } catch (e, stackTrace) {
      print('Database error: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to insert transaction: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getIncomeTransactions() async {
    Database db = await database;
    return await db.rawQuery('''
    SELECT 
      t.*,
      c.name as category_name,
      pm.name as payment_method_name
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    LEFT JOIN payment_methods pm ON t.payment_method_id = pm.id
    WHERE t.type = 'income'
    ORDER BY t.date DESC
  ''');
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT 
        t.*,
        c.name as category_name,
        pm.name as payment_method_name
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN payment_methods pm ON t.payment_method_id = pm.id
      ORDER BY t.date DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getRecentTransactions(
      {int limit = 5}) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT 
        t.*,
        c.name as category_name,
        pm.name as payment_method_name
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN payment_methods pm ON t.payment_method_id = pm.id
      ORDER BY t.date DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<int> deleteTransaction(String id) async {
    Database db = await database;

    // Get transaction details first
    final transaction = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (transaction.isEmpty) return 0;

    // Start a transaction to update both tables
    await db.transaction((txn) async {
      // Delete the transaction
      await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );

      // Reverse the balance update
      final transactionData = transaction.first;
      final amount = transactionData['amount'] as double;
      final type = transactionData['type'] as String;
      final paymentMethodId = transactionData['payment_method_id'] as String;

      // Reverse the effect on payment method balance
      await updatePaymentMethodBalance(
        paymentMethodId,
        amount,
        type == 'income' ? 'expense' : 'income',
      );
    });

    return 1;
  }

  Future<Map<String, double>> getAllBalances() async {
    Database db = await database;
    var results = await db.query('payment_methods');

    Map<String, double> balances = {};
    for (var row in results) {
      balances[row['name'] as String] = row['balance'] as double;
    }

    return balances;
  }

  // Loan Methods
  Future<int> insertLoan({
    required String id,
    required String personName,
    required double amount,
    required String type,
    required String paymentMethodId,
    String? description,
    DateTime? dueDate,
  }) async {
    Database db = await database;

    return await db.insert('loans', {
      'id': id,
      'person_name': personName,
      'amount': amount,
      'type': type,
      'status': 'pending',
      'payment_method_id': paymentMethodId,
      'description': description,
      'due_date': dueDate?.toIso8601String(),
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<int> insertLoanPayment({
    required String id,
    required String loanId,
    required double amount,
    required String paymentMethodId,
    String? description,
  }) async {
    Database db = await database;

    return await db.insert('loan_payments', {
      'id': id,
      'loan_id': loanId,
      'amount': amount,
      'payment_method_id': paymentMethodId,
      'description': description,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingLoans() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT 
        l.*,
        COALESCE(SUM(lp.amount), 0) as paid_amount,
        l.amount - COALESCE(SUM(lp.amount), 0) as remaining_amount,
        pm.name as payment_method_name
      FROM loans l
      LEFT JOIN loan_payments lp ON l.id = lp.loan_id
      LEFT JOIN payment_methods pm ON l.payment_method_id = pm.id
      WHERE l.status = 'pending'
      GROUP BY l.id
      ORDER BY l.created_at DESC
    ''');
  }

  Future<bool> verifyTransaction(String id) async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getExpenseTransactions() async {
    Database db = await database;
    return await db.rawQuery('''
    SELECT 
      t.*,
      c.name as category_name,
      pm.name as payment_method_name
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    LEFT JOIN payment_methods pm ON t.payment_method_id = pm.id
    WHERE t.type = 'expense'
    ORDER BY t.date DESC
  ''');
  }

  Future<void> debugPrintDatabaseState() async {
    Database db = await database;

    print('\n--- Current Database State ---');

    // Print all transactions
    print('\nTransactions:');
    final transactions = await db.query('transactions');
    transactions.forEach((t) => print(t));

    // Print all payment methods with balances
    print('\nPayment Methods:');
    final paymentMethods = await db.query('payment_methods');
    paymentMethods.forEach((pm) => print(pm));

    print('\n---------------------------\n');
  }

  Future<double> getTotalBalance() async {
    Database db = await database;
    var result = await db.rawQuery('''
      SELECT SUM(balance) as total_balance
      FROM payment_methods
    ''');
    return result.first['total_balance'] as double? ?? 0.0;
  }
}

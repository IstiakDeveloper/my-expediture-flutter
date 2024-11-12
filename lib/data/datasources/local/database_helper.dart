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

  Future<void> updatePaymentMethodBalance(String methodId, double amount, String type) async {
    Database db = await database;
    double currentBalance = 0.0;
    
    var result = await db.query(
      'payment_methods',
      columns: ['balance'],
      where: 'id = ?',
      whereArgs: [methodId],
    );
    
    if (result.isNotEmpty) {
      currentBalance = result.first['balance'] as double;
    }
    
    double newBalance = type == 'income' 
        ? currentBalance + amount 
        : currentBalance - amount;
    
    await db.update(
      'payment_methods',
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [methodId],
    );
  }

  // Categories Methods
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    Database db = await database;
    return await db.query('categories');
  }

  // Transaction Methods
  Future<int> insertTransaction({
    required String id,
    required String type,
    required double amount,
    required String paymentMethodId,
    String? categoryId,
    String? description,
  }) async {
    Database db = await database;
    
    // Begin transaction
    await db.transaction((txn) async {
      // Insert the transaction
      await txn.insert('transactions', {
        'id': id,
        'type': type,
        'amount': amount,
        'payment_method_id': paymentMethodId,
        'category_id': categoryId,
        'description': description,
        'date': DateTime.now().toIso8601String(),
      });
      
      // Update payment method balance
      await updatePaymentMethodBalance(paymentMethodId, amount, type);
    });
    
    return 1;
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

  Future<List<Map<String, dynamic>>> getRecentTransactions({int limit = 5}) async {
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

  Future<double> getTotalBalance() async {
    Database db = await database;
    var result = await db.rawQuery('''
      SELECT SUM(balance) as total_balance
      FROM payment_methods
    ''');
    return result.first['total_balance'] as double? ?? 0.0;
  }
}
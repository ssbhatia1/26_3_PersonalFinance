import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_tables.dart';
import 'seed_data.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  Database? _db;
  Future<Database>? _openFuture;
  bool _isInMemory = false;
  bool _seedInMemory = false;

  AppDatabase.custom(Database db) : _db = db;
  AppDatabase.inMemory({bool seedData = false})
      : _isInMemory = true,
        _seedInMemory = seedData;

  Future<Database> get database async {
    if (_db != null) return _db!;
    if (_openFuture != null) return await _openFuture!;

    _openFuture = _initDatabase();
    try {
      _db = await _openFuture!;
      return _db!;
    } finally {
      _openFuture = null;
    }
  }

  Future<Database> _initDatabase() async {
    // Enable FFI for desktop platforms
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    if (_isInMemory) {
      return await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: (db, version) async {
            await _upgradeSchema(db);
            await _createTables(db);
            await _upgradeSchema(db);
            if (_seedInMemory) {
              await _seedInitialData(db, includeDemo: true);
            }
            await _ensureDemoUser(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            await _upgradeSchema(db);
            await _createTables(db);
            await _upgradeSchema(db);
            await _ensureDemoUser(db);
          },
        ),
      );
    }

    final dbPath = await _getDatabasePath();
    debugPrint('Opening SQLite database at: $dbPath');

    final databaseInstance = await openDatabase(
      dbPath,
      version: 9,
      onConfigure: (db) async {
        // Enable foreign key constraints in SQLite
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _upgradeSchema(db);
        await _createTables(db);
        await _upgradeSchema(db);
        await cleanUntokenizedData(db);
        await _seedInitialData(db, includeDemo: false);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('Upgrading database from version $oldVersion to $newVersion');
        await _upgradeSchema(db);
        await _createTables(db);
        await _upgradeSchema(db);
        await cleanUntokenizedData(db);
        await _ensureDemoUser(db);
      },
      onOpen: (db) async {
        // Guarantee all columns and tables exist even if opened from an older database version without migration
        await _upgradeSchema(db);
        await _createTables(db);
        await _upgradeSchema(db);
        await cleanUntokenizedData(db);
        await _ensureDemoUser(db);
      },
    );
    return databaseInstance;
  }

  Future<void> _upgradeSchema(DatabaseExecutor db) async {
    // 1. Accounts table column upgrades
    try {
      await db.execute('ALTER TABLE accounts ADD COLUMN user_id TEXT;');
    } catch (_) {}
    try {
      await db.execute("UPDATE accounts SET user_id = 'usr_demo_primary' WHERE user_id IS NULL;");
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE accounts ADD COLUMN account_token TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE accounts ADD COLUMN institution TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE accounts ADD COLUMN masked_reference TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE accounts ADD COLUMN credit_limit REAL DEFAULT 0.0;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE accounts ADD COLUMN interest_rate REAL DEFAULT 0.0;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE accounts ADD COLUMN opened_at TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE accounts ADD COLUMN notes TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE accounts ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;');
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE accounts ADD COLUMN currency TEXT NOT NULL DEFAULT 'INR';");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE accounts ADD COLUMN status TEXT NOT NULL DEFAULT 'active';");
    } catch (_) {}

    // 2. Transactions table column upgrades
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN payee_payer TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN payment_method TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN reference_number TEXT;');
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE transactions ADD COLUMN status TEXT NOT NULL DEFAULT 'completed';");
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN is_recurring_instance_of TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN notes TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN is_reconciled INTEGER NOT NULL DEFAULT 0;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN created_at TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN updated_at TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;');
    } catch (_) {}

    // 3. Budgets table column upgrades
    try {
      await db.execute('ALTER TABLE budgets ADD COLUMN name TEXT;');
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE budgets ADD COLUMN scope TEXT NOT NULL DEFAULT 'category';");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE budgets ADD COLUMN period_type TEXT NOT NULL DEFAULT 'monthly';");
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE budgets ADD COLUMN is_recurring INTEGER NOT NULL DEFAULT 0;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE budgets ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;');
    } catch (_) {}

    // 4. Recurring transactions table column upgrades
    try {
      await db.execute('ALTER TABLE recurring_transactions ADD COLUMN is_flexible_amount INTEGER NOT NULL DEFAULT 0;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE recurring_transactions ADD COLUMN interval_count INTEGER NOT NULL DEFAULT 1;');
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE recurring_transactions ADD COLUMN interval_unit TEXT NOT NULL DEFAULT 'months';");
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE recurring_transactions ADD COLUMN last_executed_at TEXT;');
    } catch (_) {}

    // 5. Loans table column upgrades
    try {
      await db.execute('ALTER TABLE loans ADD COLUMN is_flexible_interest INTEGER NOT NULL DEFAULT 0;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE loans ADD COLUMN emi_amount REAL DEFAULT 0.0;');
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE loans ADD COLUMN status TEXT NOT NULL DEFAULT 'active';");
    } catch (_) {}

    // 6. Financial goals table column upgrades
    try {
      await db.execute("ALTER TABLE financial_goals ADD COLUMN icon TEXT NOT NULL DEFAULT 'savings';");
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE financial_goals ADD COLUMN is_completed INTEGER NOT NULL DEFAULT 0;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE financial_goals ADD COLUMN linked_account_id TEXT;');
    } catch (_) {}

    // 7. Attachments table column upgrades
    try {
      await db.execute('ALTER TABLE attachments ADD COLUMN account_id TEXT;');
    } catch (_) {}

    // 8. Auxiliary and feature tables
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS loan_repayments (
          id TEXT PRIMARY KEY,
          loan_id TEXT NOT NULL,
          payment_amount REAL NOT NULL,
          principal_amount REAL NOT NULL,
          interest_amount REAL NOT NULL DEFAULT 0.0,
          payment_date TEXT NOT NULL,
          account_id TEXT NOT NULL,
          transaction_id TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE,
          FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT
        );
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS investments (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          account_id TEXT,
          invested_amount REAL NOT NULL DEFAULT 0.0,
          current_value REAL NOT NULL DEFAULT 0.0,
          expected_return_rate REAL NOT NULL DEFAULT 0.0,
          start_date TEXT NOT NULL,
          maturity_date TEXT,
          frequency TEXT,
          maturity_amount REAL,
          notes TEXT,
          status TEXT NOT NULL DEFAULT 'active',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE SET NULL
        );
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS account_adjustments (
          id TEXT PRIMARY KEY,
          account_id TEXT NOT NULL,
          previous_balance REAL NOT NULL,
          new_balance REAL NOT NULL,
          adjustment_amount REAL NOT NULL,
          adjustment_type TEXT NOT NULL,
          reason TEXT NOT NULL,
          created_at TEXT NOT NULL,
          transaction_id TEXT,
          FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
          FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
        );
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payment_records (
          id TEXT PRIMARY KEY,
          schedule_id TEXT,
          transaction_id TEXT,
          title TEXT NOT NULL,
          source_account_id TEXT NOT NULL,
          destination_account_id TEXT,
          type TEXT NOT NULL,
          category_id TEXT,
          amount REAL NOT NULL,
          is_flexible INTEGER NOT NULL DEFAULT 0,
          due_date TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'scheduled',
          execution_date TEXT,
          notes TEXT,
          failure_reason TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (schedule_id) REFERENCES recurring_transactions(id) ON DELETE SET NULL,
          FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL,
          FOREIGN KEY (source_account_id) REFERENCES accounts(id) ON DELETE CASCADE,
          FOREIGN KEY (destination_account_id) REFERENCES accounts(id) ON DELETE SET NULL,
          FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
        );
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sensitive_tokens (
          token_id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          masked_value TEXT NOT NULL,
          tokenized_surrogate TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_sessions (
          token TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          created_at TEXT NOT NULL,
          expires_at TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          email TEXT UNIQUE NOT NULL,
          username TEXT UNIQUE NOT NULL,
          full_name TEXT NOT NULL,
          password_hash TEXT NOT NULL,
          salt TEXT NOT NULL,
          reset_token TEXT,
          reset_token_expiry TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
    } catch (_) {}

    // 9. Safe indices creation
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_user ON accounts (user_id);');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_type ON accounts (type);');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_token ON accounts (account_token);');
    } catch (_) {}

    // 10. Purge untokenized data, demo accounts, and orphan records
    await cleanUntokenizedData(db);
  }

  /// Permanently removes untokenized data, sample accounts, and orphan records
  Future<void> cleanUntokenizedData([DatabaseExecutor? executor]) async {
    final db = executor ?? await database;
    try {
      // 1. Delete all sample / demo accounts and their transactions / records
      await db.delete(
        DatabaseTables.transactions,
        where: "source_account_id LIKE 'acc_demo_%' OR destination_account_id LIKE 'acc_demo_%'",
      );
      await db.delete(
        DatabaseTables.paymentRecords,
        where: "source_account_id LIKE 'acc_demo_%' OR destination_account_id LIKE 'acc_demo_%'",
      );
      await db.delete(
        DatabaseTables.accountAdjustments,
        where: "account_id LIKE 'acc_demo_%'",
      );
      await db.delete(
        DatabaseTables.loans,
        where: "account_id LIKE 'acc_demo_%'",
      );
      await db.delete(
        DatabaseTables.investments,
        where: "account_id LIKE 'acc_demo_%'",
      );
      await db.delete(
        DatabaseTables.sensitiveTokens,
        where: "token_id LIKE 'tok_id_acc_demo_%' OR user_id = 'usr_demo_primary'",
      );
      await db.delete(
        DatabaseTables.accounts,
        where: "id LIKE 'acc_demo_%'",
      );

      // 2. Delete any untokenized accounts (where account_token IS NULL or empty)
      await db.delete(
        DatabaseTables.accounts,
        where: "account_token IS NULL OR account_token = ''",
      );

      // 3. Delete any transactions referencing non-existent or untokenized accounts
      await db.delete(
        DatabaseTables.transactions,
        where: "source_account_id NOT IN (SELECT id FROM accounts WHERE account_token IS NOT NULL AND account_token != '')",
      );

      // 4. Clean orphan / untokenized payment records
      await db.delete(
        DatabaseTables.paymentRecords,
        where: "source_account_id NOT IN (SELECT id FROM accounts WHERE account_token IS NOT NULL AND account_token != '')",
      );

      // 5. Clean orphan / untokenized account adjustments
      await db.delete(
        DatabaseTables.accountAdjustments,
        where: "account_id NOT IN (SELECT id FROM accounts WHERE account_token IS NOT NULL AND account_token != '')",
      );

      // 6. Clean orphan / untokenized loans
      await db.delete(
        DatabaseTables.loans,
        where: "account_id NOT IN (SELECT id FROM accounts WHERE account_token IS NOT NULL AND account_token != '')",
      );

      // 7. Clean orphan loan repayments
      await db.delete(
        DatabaseTables.loanRepayments,
        where: "account_id NOT IN (SELECT id FROM accounts WHERE account_token IS NOT NULL AND account_token != '')",
      );

      // 8. Clean orphan investments
      await db.delete(
        DatabaseTables.investments,
        where: "account_id IS NOT NULL AND account_id != '' AND account_id NOT IN (SELECT id FROM accounts WHERE account_token IS NOT NULL AND account_token != '')",
      );

      // 9. Clean orphan attachments
      await db.delete(
        DatabaseTables.attachments,
        where: "account_id IS NOT NULL AND account_id != '' AND account_id NOT IN (SELECT id FROM accounts WHERE account_token IS NOT NULL AND account_token != '')",
      );
    } catch (e) {
      debugPrint('Notice during cleanUntokenizedData: $e');
    }
  }

  /// Returns the resolved database path (folder-based for portable builds, documents for installed)
  Future<String> get databasePath => _getDatabasePath();

  Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      return 'personal_finance.db';
    }

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final exeDir = p.dirname(Platform.resolvedExecutable);

        // 1. Direct database file in application folder
        final localDbInExeDir = File(p.join(exeDir, 'personal_finance_app.db'));
        if (localDbInExeDir.existsSync()) {
          debugPrint('Using local database in executable directory: ${localDbInExeDir.path}');
          return localDbInExeDir.path;
        }

        // 2. Database inside data/ subfolder of application folder
        final localDbInDataDir = File(p.join(exeDir, 'data', 'personal_finance_app.db'));
        if (localDbInDataDir.existsSync()) {
          debugPrint('Using local database in application data folder: ${localDbInDataDir.path}');
          return localDbInDataDir.path;
        }

        // 3. Portable marker checks (.portable, portable.txt, is_portable)
        final hasPortableMarker = File(p.join(exeDir, '.portable')).existsSync() ||
            File(p.join(exeDir, 'portable.txt')).existsSync() ||
            File(p.join(exeDir, 'is_portable')).existsSync();

        // 4. Also check if running in a non-system folder (portable zip extraction or developer folder)
        final isSystemFolder = Platform.isWindows
            ? (exeDir.toLowerCase().contains('program files') || exeDir.toLowerCase().contains(r'windows\system32'))
            : (exeDir.startsWith('/usr') || exeDir.startsWith('/bin') || exeDir.startsWith('/opt'));

        if (hasPortableMarker || !isSystemFolder) {
          // Portable mode / folder build: store data inside the application folder
          final dataDir = Directory(p.join(exeDir, 'data'));
          final targetDbFile = dataDir.existsSync()
              ? File(p.join(dataDir.path, 'personal_finance_app.db'))
              : File(p.join(exeDir, 'personal_finance_app.db'));

          // If the database doesn't exist yet in the folder, check if there is an existing database in Documents to migrate over
          if (!targetDbFile.existsSync()) {
            try {
              final appDocDir = await getApplicationDocumentsDirectory();
              final existingDocDb = File(p.join(appDocDir.path, 'personal_finance_app.db'));
              if (existingDocDb.existsSync()) {
                debugPrint('Migrating existing database from Documents into folder: ${targetDbFile.path}');
                if (!targetDbFile.parent.existsSync()) {
                  targetDbFile.parent.createSync(recursive: true);
                }
                existingDocDb.copySync(targetDbFile.path);
              }
            } catch (e) {
              debugPrint('Notice migrating existing documents database: $e');
            }
          }

          debugPrint('Using folder database: ${targetDbFile.path}');
          return targetDbFile.path;
        }
      } catch (e) {
        debugPrint('Notice determining local database path: $e');
      }
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    return p.join(appDocDir.path, 'personal_finance_app.db');
  }

  Future<void> _createTables(DatabaseExecutor db) async {
    for (final statement in DatabaseTables.createTableStatements) {
      try {
        await db.execute(statement);
      } catch (e) {
        debugPrint('Notice executing table/index statement: $e');
      }
    }
  }

  Future<void> _seedInitialData(DatabaseExecutor db, {bool includeDemo = false}) async {
    for (final cat in SeedData.defaultCategories) {
      await db.insert(
        DatabaseTables.categories,
        cat,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    if (includeDemo) {
      for (final acc in SeedData.defaultAccounts) {
        await db.insert(
          DatabaseTables.accounts,
          acc,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      for (final tx in SeedData.generateDemoTransactions()) {
        await db.insert(
          DatabaseTables.transactions,
          tx,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    await db.insert(
      DatabaseTables.settings,
      {'key': 'currency', 'value': '₹'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      DatabaseTables.settings,
      {'key': 'theme_mode', 'value': 'light'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      DatabaseTables.settings,
      {'key': 'has_seeded_demo', 'value': 'true'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    debugPrint('SQLite database initialized with default seed data.');
  }

  /// Wipe and reseed demo data (useful for resets)
  Future<void> resetToDemoData() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final statement in [
        'DELETE FROM ${DatabaseTables.userSessions};',
        'DELETE FROM ${DatabaseTables.sensitiveTokens};',
        'DELETE FROM ${DatabaseTables.users};',
        'DELETE FROM ${DatabaseTables.accountAdjustments};',
        'DELETE FROM ${DatabaseTables.investments};',
        'DELETE FROM ${DatabaseTables.financialGoals};',
        'DELETE FROM ${DatabaseTables.loanRepayments};',
        'DELETE FROM ${DatabaseTables.loans};',
        'DELETE FROM ${DatabaseTables.paymentRecords};',
        'DELETE FROM ${DatabaseTables.recurringTransactions};',
        'DELETE FROM ${DatabaseTables.budgets};',
        'DELETE FROM ${DatabaseTables.attachments};',
        'DELETE FROM ${DatabaseTables.transactions};',
        'DELETE FROM ${DatabaseTables.accounts};',
        'DELETE FROM ${DatabaseTables.categories};',
        'DELETE FROM ${DatabaseTables.auditLogs};',
      ]) {
        await txn.execute(statement);
      }

      final batch = txn.batch();
      batch.insert(DatabaseTables.users, SeedData.getDefaultDemoUser());
      for (final cat in SeedData.defaultCategories) {
        batch.insert(DatabaseTables.categories, cat);
      }
      for (final acc in SeedData.defaultAccounts) {
        batch.insert(DatabaseTables.accounts, acc);
      }
      for (final tx in SeedData.generateDemoTransactions()) {
        batch.insert(DatabaseTables.transactions, tx);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Completely wipe all personal financial data from the database (clean slate, no dummy data)
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final statement in [
        'DELETE FROM ${DatabaseTables.accountAdjustments};',
        'DELETE FROM ${DatabaseTables.investments};',
        'DELETE FROM ${DatabaseTables.financialGoals};',
        'DELETE FROM ${DatabaseTables.loanRepayments};',
        'DELETE FROM ${DatabaseTables.loans};',
        'DELETE FROM ${DatabaseTables.paymentRecords};',
        'DELETE FROM ${DatabaseTables.recurringTransactions};',
        'DELETE FROM ${DatabaseTables.budgets};',
        'DELETE FROM ${DatabaseTables.attachments};',
        'DELETE FROM ${DatabaseTables.transactions};',
        'DELETE FROM ${DatabaseTables.accounts};',
        'DELETE FROM ${DatabaseTables.auditLogs};',
      ]) {
        await txn.execute(statement);
      }

      // Ensure standard categories exist so user can immediately categorize new entries
      final res = await txn.rawQuery('SELECT COUNT(*) AS count FROM ${DatabaseTables.categories}');
      final catCount = (res.isNotEmpty ? res.first['count'] as num? : null)?.toInt() ?? 0;
      if (catCount == 0) {
        final batch = txn.batch();
        for (final cat in SeedData.defaultCategories) {
          batch.insert(DatabaseTables.categories, cat);
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<void> _ensureDemoUser(DatabaseExecutor db) async {
    try {
      await db.insert(
        DatabaseTables.users,
        SeedData.getDefaultDemoUser(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      debugPrint('Default demo user ensured in SQLite database.');
    } catch (e) {
      debugPrint('Error ensuring demo user: $e');
    }
  }

  /// Ensure all tables and seed data exist even if upgraded
  Future<void> ensureTablesAndDemoUser() async {
    await database;
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}

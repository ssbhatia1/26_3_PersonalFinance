class DatabaseTables {
  DatabaseTables._();

  static const String accounts = 'accounts';
  static const String categories = 'categories';
  static const String transactions = 'transactions';
  static const String budgets = 'budgets';
  static const String recurringTransactions = 'recurring_transactions';
  static const String loans = 'loans';
  static const String financialGoals = 'financial_goals';
  static const String auditLogs = 'audit_logs';
  static const String settings = 'settings';
  static const String users = 'users';
  static const String userSessions = 'user_sessions';
  static const String sensitiveTokens = 'sensitive_tokens';
  static const String attachments = 'attachments';
  static const String paymentRecords = 'payment_records';
  static const String loanRepayments = 'loan_repayments';
  static const String investments = 'investments';
  static const String accountAdjustments = 'account_adjustments';

  static const List<String> createTableStatements = [
    '''
    CREATE TABLE IF NOT EXISTS accounts (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      account_token TEXT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      institution TEXT,
      masked_reference TEXT,
      opening_balance REAL NOT NULL DEFAULT 0.0,
      current_balance REAL NOT NULL DEFAULT 0.0,
      currency TEXT NOT NULL DEFAULT 'INR',
      status TEXT NOT NULL DEFAULT 'active',
      credit_limit REAL DEFAULT 0.0,
      interest_rate REAL DEFAULT 0.0,
      opened_at TEXT,
      notes TEXT,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      icon TEXT NOT NULL,
      color TEXT NOT NULL,
      parent_id TEXT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY,
      source_account_id TEXT NOT NULL,
      destination_account_id TEXT,
      type TEXT NOT NULL,
      category_id TEXT,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      description TEXT,
      payee_payer TEXT,
      payment_method TEXT,
      reference_number TEXT,
      status TEXT NOT NULL DEFAULT 'completed',
      is_recurring_instance_of TEXT,
      notes TEXT,
      is_reconciled INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (source_account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
      FOREIGN KEY (destination_account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
      FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS budgets (
      id TEXT PRIMARY KEY,
      name TEXT,
      category_id TEXT,
      scope TEXT NOT NULL DEFAULT 'category',
      period_type TEXT NOT NULL DEFAULT 'monthly',
      amount_limit REAL NOT NULL,
      start_date TEXT NOT NULL,
      end_date TEXT NOT NULL,
      is_recurring INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS recurring_transactions (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      source_account_id TEXT NOT NULL,
      destination_account_id TEXT,
      type TEXT NOT NULL,
      category_id TEXT,
      amount REAL NOT NULL,
      frequency TEXT NOT NULL,
      start_date TEXT NOT NULL,
      end_date TEXT,
      next_execution_date TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      last_executed_at TEXT,
      is_flexible_amount INTEGER NOT NULL DEFAULT 0,
      interval_count INTEGER NOT NULL DEFAULT 1,
      interval_unit TEXT NOT NULL DEFAULT 'months',
      FOREIGN KEY (source_account_id) REFERENCES accounts(id) ON DELETE CASCADE,
      FOREIGN KEY (destination_account_id) REFERENCES accounts(id) ON DELETE SET NULL,
      FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS loans (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      borrower_lender_name TEXT NOT NULL,
      loan_type TEXT NOT NULL,
      principal REAL NOT NULL,
      interest_rate REAL NOT NULL DEFAULT 0.0,
      is_flexible_interest INTEGER NOT NULL DEFAULT 0,
      term_months INTEGER NOT NULL DEFAULT 12,
      outstanding_balance REAL NOT NULL,
      start_date TEXT NOT NULL,
      emi_amount REAL DEFAULT 0.0,
      status TEXT NOT NULL DEFAULT 'active',
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
    );
    ''',
    '''
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
    ''',
    '''
    CREATE TABLE IF NOT EXISTS financial_goals (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      target_amount REAL NOT NULL,
      current_amount REAL NOT NULL DEFAULT 0.0,
      target_date TEXT NOT NULL,
      linked_account_id TEXT,
      icon TEXT NOT NULL DEFAULT 'savings',
      is_completed INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (linked_account_id) REFERENCES accounts(id) ON DELETE SET NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS audit_logs (
      id TEXT PRIMARY KEY,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      action TEXT NOT NULL,
      previous_value_json TEXT,
      new_value_json TEXT,
      timestamp TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    ''',
    '''
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
    ''',
    '''
    CREATE TABLE IF NOT EXISTS user_sessions (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS sensitive_tokens (
      token_id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      masked_value TEXT NOT NULL,
      tokenized_surrogate TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS attachments (
      id TEXT PRIMARY KEY,
      transaction_id TEXT,
      account_id TEXT,
      file_name TEXT NOT NULL,
      file_path TEXT NOT NULL,
      file_type TEXT NOT NULL,
      file_size INTEGER NOT NULL DEFAULT 0,
      uploaded_at TEXT NOT NULL,
      FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
    );
    ''',
    '''
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
    ''',
    '''
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
    ''',
    '''
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
    ''',
    // Create indices for high-performance querying
    'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions (date);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_source ON transactions (source_account_id);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_dest ON transactions (destination_account_id);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions (type);',
    'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions (category_id);',
    'CREATE INDEX IF NOT EXISTS idx_accounts_type ON accounts (type);',
    'CREATE INDEX IF NOT EXISTS idx_accounts_user ON accounts (user_id);',
    'CREATE INDEX IF NOT EXISTS idx_accounts_token ON accounts (account_token);',
    'CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);',
    'CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);',
    'CREATE INDEX IF NOT EXISTS idx_sessions_user ON user_sessions (user_id);',
    'CREATE INDEX IF NOT EXISTS idx_attachments_tx ON attachments (transaction_id);',
    'CREATE INDEX IF NOT EXISTS idx_payment_records_status ON payment_records (status);',
    'CREATE INDEX IF NOT EXISTS idx_payment_records_due ON payment_records (due_date);',
    'CREATE INDEX IF NOT EXISTS idx_payment_records_schedule ON payment_records (schedule_id);',
    'CREATE INDEX IF NOT EXISTS idx_investments_type ON investments (type);',
    'CREATE INDEX IF NOT EXISTS idx_investments_account ON investments (account_id);',
    'CREATE INDEX IF NOT EXISTS idx_investments_status ON investments (status);',
    'CREATE INDEX IF NOT EXISTS idx_adjustments_account ON account_adjustments (account_id);',
    'CREATE INDEX IF NOT EXISTS idx_adjustments_date ON account_adjustments (created_at);',
  ];
}

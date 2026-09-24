class Tables {
  static const String books = 'books';
  static const String accounts = 'accounts';
  static const String categories = 'categories';
  static const String parties = 'parties';
  static const String transactions = 'transactions';
  static const String auditLogs = 'audit_logs';

  static const String createBooksTable = '''
    CREATE TABLE $books (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      currency TEXT NOT NULL,
      opening_balance_minor INTEGER NOT NULL DEFAULT 0,
      opening_balance_date TEXT NOT NULL,
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  static const String createAccountsTable = '''
    CREATE TABLE $accounts (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      opening_balance_minor INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(book_id) REFERENCES $books(id) ON DELETE CASCADE
    );
  ''';

  static const String createCategoriesTable = '''
    CREATE TABLE $categories (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      icon TEXT NOT NULL,
      color INTEGER NOT NULL,
      is_default INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY(book_id) REFERENCES $books(id) ON DELETE CASCADE
    );
  ''';

  static const String createPartiesTable = '''
    CREATE TABLE $parties (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      name TEXT NOT NULL,
      phone TEXT,
      email TEXT,
      type TEXT NOT NULL,
      notes TEXT,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(book_id) REFERENCES $books(id) ON DELETE CASCADE
    );
  ''';

  static const String createTransactionsTable = '''
    CREATE TABLE $transactions (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      account_id TEXT,
      party_id TEXT,
      category_id TEXT,
      type TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      date TEXT NOT NULL,
      time TEXT NOT NULL,
      description TEXT,
      payment_method TEXT,
      reference_number TEXT,
      attachment_path TEXT,
      transfer_id TEXT,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      deleted_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(book_id) REFERENCES $books(id) ON DELETE CASCADE,
      FOREIGN KEY(account_id) REFERENCES $accounts(id) ON DELETE SET NULL,
      FOREIGN KEY(party_id) REFERENCES $parties(id) ON DELETE SET NULL,
      FOREIGN KEY(category_id) REFERENCES $categories(id) ON DELETE SET NULL
    );
  ''';

  static const String createAuditLogsTable = '''
    CREATE TABLE $auditLogs (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      action TEXT NOT NULL,
      details TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      FOREIGN KEY(book_id) REFERENCES $books(id) ON DELETE CASCADE
    );
  ''';

  // Indexes for high performance querying across thousands of transactions
  static const List<String> createIndexes = [
    'CREATE INDEX idx_tx_book ON $transactions(book_id);',
    'CREATE INDEX idx_tx_date ON $transactions(date);',
    'CREATE INDEX idx_tx_type ON $transactions(type);',
    'CREATE INDEX idx_tx_party ON $transactions(party_id);',
    'CREATE INDEX idx_tx_category ON $transactions(category_id);',
    'CREATE INDEX idx_tx_account ON $transactions(account_id);',
    'CREATE INDEX idx_tx_deleted ON $transactions(is_deleted);',
    'CREATE INDEX idx_parties_book ON $parties(book_id);',
    'CREATE INDEX idx_categories_book ON $categories(book_id);',
    'CREATE INDEX idx_accounts_book ON $accounts(book_id);',
  ];
}

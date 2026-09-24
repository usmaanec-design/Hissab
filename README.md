# Hissab (حساب) - Professional CashBook & Ledger

Hissab is an original, production-ready, offline-first mobile and desktop financial ledger application built with Flutter, Dart, and SQLite. Engineered for personal expense tracking and small-to-medium enterprise cash management, Hissab replaces paper cashbooks, khatas, and manual registers with deterministic, auditable accounting precision.

---

## 🌟 Key Capabilities

### 1. Deterministic Financial Precision (Zero Floating-Point Error)
- **Smallest Minor Unit Storage**: Monetary amounts are stored internally as 64-bit integer minor units (e.g. `100.50 SAR` = `10050` halalas, `100.50 PKR` = `10050` paisas).
- **Deterministic Math**: Completely avoids binary floating-point errors (such as `0.1 + 0.2 = 0.30000000000000004`).
- **Large Number Safety**: Stress-tested up to `999,999,999.99` with zero integer overflow or rounding degradation.
- **Negative Balance Handling**: Accurately tracks overdrafts and negative balances without corrupting signs.

### 2. Multi-Book Architecture
- Create independent books (e.g., *"Main Business"*, *"Personal"*, *"Retail Shop"*, *"Saudi Expenses"*, *"Pakistan Expenses"*).
- Each book maintains its own base currency, opening balance, accounts, categories, parties, and ledger journal.
- Transactions between books are strictly isolated and never bleed into other books.
- Books can be renamed, archived, unarchived, or permanently deleted with safety confirmation.

### 3. Rapid 3-Second Transaction Flow
- Custom built-in numeric keypad with instant validation and dynamic currency formatting.
- Quick single-tap category chips, optional party selector, payment method dropdown, and receipt reference.
- Instant balance recalculation on save, edit, soft-delete, and restoration.

### 4. Separate Cash / Bank Accounts & Internal Transfers
- Manage multiple financial channels: **Cash in Hand**, **Bank Account**, **Card / Mada**, and **Digital Wallets (STC Pay)**.
- **Zero-Sum Internal Transfers**: Move funds between accounts (e.g. `Cash -> Bank`). The transfer debits the source account and credits the destination account while leaving overall cashbook income/expense neutral.

### 5. Contact / Party Ledgers (Khata)
- Track **Customers**, **Suppliers**, and **Employees**.
- **Customer Statement**: Total Invoiced/Sales, Total Received, and Remaining Receivable (owed to you).
- **Supplier Statement**: Total Purchases, Total Paid, and Remaining Payable (you owe).
- Filter transactions by party and export statement ledgers.

### 6. Reports & Visual Analytics
- Daily, Weekly, Monthly, Yearly, and Custom period filtering.
- Total Income, Total Expense, and Net Cash Flow summaries.
- Interactive category expense breakdown donut chart (`fl_chart`).
- Safe percentage calculations protected against `0/0` division (`NaN` / `Infinity`).

### 7. Professional Export Engines
- **Branded PDF Cashbook Report**: Generates A4 statements with company header, date range, summary stat boxes, transaction tables, and pagination.
- **Printable Payment Receipts**: Generates A5 printable receipts with custom receipt numbers (`HS-YYYY-XXXX`), party name, amount, payment method, and signature block.
- **CSV / Excel Export**: Full transaction journal with computed running balance.
- **Full Database JSON Backup & Restore**: Complete atomic database export and rollback-protected restoration.

### 8. Security & Audit Trail
- **Salted SHA-256 PIN Lock**: 4-digit security PIN protecting sensitive financial data.
- **Ledger Audit & Balance Reconciliation**: Built-in diagnostic tool verifying that displayed balances match 100% of underlying journal entries.
- **Chronological Audit Trail**: Logs every create, update, delete, and restore action.
- **Soft Deletion (`isDeleted = 1`)**: Financial records are never silently erased, protecting accounting integrity.

### 9. Multi-Language & Native RTL Support
- Supported languages: **English**, **العربية (Arabic - RTL)**, and **اردو (Urdu - RTL)**.
- Proper bidirectional text layout with localized strings and numeric formats.

---

## 🏛️ Architecture & Folder Structure

Built using Clean Architecture principles separating Data, Domain, and Presentation:

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   └── currencies.dart              # Multi-currency config (SAR, PKR, USD, AED, EUR, GBP, etc.)
│   ├── localization/
│   │   └── app_localizations.dart       # English, Arabic (RTL), and Urdu (RTL) localization
│   ├── security/
│   │   └── security_service.dart        # Salted SHA-256 PIN hashing & auth
│   ├── theme/
│   │   ├── app_colors.dart              # Semantic financial color tokens (Money In, Money Out)
│   │   └── app_theme.dart               # Material 3 Light & Dark mode configurations
│   └── utils/
│       ├── currency_formatter.dart      # Format minor units to comma-separated strings
│       ├── date_formatter.dart          # Local timezone date formatting & ISO ranges
│       └── decimal_calculator.dart      # Deterministic minor unit math & safe percentages
├── data/
│   ├── database/
│   │   ├── app_database.dart            # SQLite lifecycle, FFI desktop bridge, and seeders
│   │   └── tables.dart                  # Table definitions, foreign keys, and indexed columns
│   ├── models/
│   │   ├── account_model.dart           # Cash/Bank account schema
│   │   ├── audit_model.dart             # Audit event schema
│   │   ├── book_model.dart              # Multi-book schema
│   │   ├── category_model.dart          # Income/Expense classification schema
│   │   ├── party_model.dart             # Customer/Supplier schema
│   │   └── transaction_model.dart       # Financial transaction schema
│   └── repositories/
│       ├── account_repository.dart
│       ├── audit_repository.dart
│       ├── backup_repository.dart       # PDF reports, receipts, CSV, and JSON backup/restore
│       ├── book_repository.dart
│       ├── category_repository.dart
│       ├── party_repository.dart
│       └── transaction_repository.dart  # Atomic transactions, pagination, filters
├── domain/
│   └── accounting/
│       ├── accounting_engine.dart       # Deterministic formulas & ledger summaries
│       └── balance_reconciliation.dart  # Audit reconciliation diagnostic
├── presentation/
│   ├── controllers/
│   │   ├── account_controller.dart
│   │   ├── app_controller.dart          # Theme, Locale, and PIN state
│   │   ├── book_controller.dart         # Multi-book switching
│   │   ├── category_controller.dart
│   │   ├── party_controller.dart        # Customer/Supplier ledgers
│   │   └── transaction_controller.dart  # Journal & balance state
│   ├── screens/
│   │   ├── accounts/                    # Cash & Bank accounts with internal transfer
│   │   ├── books/                       # Books management & archiving
│   │   ├── categories/                  # Categories management
│   │   ├── home/                        # Dashboard & Main Scaffold
│   │   ├── onboarding/                  # First launch book setup
│   │   ├── parties/                     # Parties & individual party ledgers
│   │   ├── receipt/                     # Printable payment receipt preview & export
│   │   ├── reports/                     # Donut charts, filters, PDF/CSV export
│   │   ├── security/                    # PIN lock screen
│   │   ├── settings/                    # Preferences, backup/restore, audit logs
│   │   └── transactions/                # Fast entry, search, filters, details
│   └── widgets/
│       ├── amount_keypad.dart           # Fast numeric keypad
│       ├── balance_card.dart            # Hero balance banner
│       ├── quick_action_bar.dart        # High-contrast Money In / Money Out buttons
│       └── transaction_tile.dart        # Semantic transaction card
└── main.dart                            # MultiProvider root & bootstrap
```

---

## 🗄️ Database Schema & Indexes

All data is stored locally in an offline-first SQLite database (`hissab_v1.db`):

| Table | Primary Key | Key Foreign Keys | Purpose |
| :--- | :--- | :--- | :--- |
| `books` | `id (TEXT)` | - | Stores book name, currency, opening balance, and archive status |
| `accounts` | `id (TEXT)` | `book_id -> books(id)` | Cash, Bank, and Digital Wallet ledgers |
| `categories` | `id (TEXT)` | `book_id -> books(id)` | Income and expense tags with color and icon |
| `parties` | `id (TEXT)` | `book_id -> books(id)` | Customer, Supplier, and Employee contact ledgers |
| `transactions`| `id (TEXT)` | `book_id`, `account_id`, `party_id`, `category_id` | Core auditable journal entries |
| `audit_logs` | `id (TEXT)` | `book_id -> books(id)` | Chronological log of creates, edits, and deletions |

### High-Performance Indexes
- `idx_tx_book`: Accelerated queries scoped to active book
- `idx_tx_date`: Fast date range filtering (Today, This Month, This Year)
- `idx_tx_type`: Instant Money In / Money Out filtering
- `idx_tx_party`: Rapid party statement generation
- `idx_tx_account`: Fast cash/bank account balance recalculations
- `idx_tx_deleted`: Instant filtering of non-deleted active transactions

---

## 🧪 Automated Test Suite (101 Tests)

Hissab includes a comprehensive automated test suite (`test/accounting_engine_test.dart`) covering 101 test scenarios:
1. **Core Accounting Formulas**: Opening balance + In - Out across zero, positive, and negative balances.
2. **Negative Overdrafts**: Accurately tracks negative balances without arbitrary sign inversions.
3. **Large Numbers**: Validates calculations up to `999,999,999.99` with zero overflow.
4. **Soft Deletion & Restoration**: Verifies that deleted records are excluded from balances and restored records update balances immediately.
5. **Zero-Sum Internal Transfers**: Proves that moving money between Cash and Bank does not alter net book cash flow.
6. **Customer & Supplier Statements**: Verifies accurate calculation of receivables, payables, and outstanding balances.
7. **Minor Unit Parser & Formatting**: Exhaustive testing of decimal parsing, padding, and edge-case inputs.
8. **Reconciliation Auditing**: Confirms detection of any discrepancy between displayed and computed ledger balances.
9. **Multi-Book Isolation**: Verifies that transactions in Book A never alter Book B.

To run the test suite:
```bash
flutter test test/accounting_engine_test.dart
```

---

## 🚀 Building & Running

### Prerequisites
- Flutter SDK 3.32+
- Dart SDK 3.8+
- Android Studio / Android SDK (for Android builds)

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run Locally
- **Desktop (Windows/macOS/Linux)**:
  ```bash
  flutter run -d windows
  ```
- **Android Device / Emulator**:
  ```bash
  flutter run -d android
  ```

### 3. Build Production Android Release
- **Release APK**:
  ```bash
  flutter build apk --release
  ```
  The generated APK will be located at:
  `build/app/outputs/flutter-apk/app-release.apk`

- **Release App Bundle (AAB for Google Play)**:
  ```bash
  flutter build appbundle --release
  ```
  The generated bundle will be located at:
  `build/app/outputs/bundle/release/app-release.aab`

---

## 🔒 Security & Privacy
- **100% Offline-First**: All data remains exclusively on the user's device. No telemetry or unexpected cloud uploads.
- **PIN Protection**: User PIN is protected with salted SHA-256 hashing.
- **Audit Logging**: Every financial transaction and book update is logged in the audit journal.

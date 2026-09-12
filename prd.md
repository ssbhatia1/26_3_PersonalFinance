# Product Requirements Document
## Personal Finance, Income & Expense Management System
### Platform: Flutter (Mobile + Desktop + Tablet) | Local-First Architecture

**Version:** 1.0
**Document Type:** PRD
**Target Stack:** Flutter, Riverpod, SQLite (local), MVVM, fl_chart

---

## 1. Executive Summary

This PRD defines a comprehensive, offline-first Personal Finance Management application built in Flutter. The app gives an individual user a single source of truth for all money movement — income, expenses, transfers, credit cards, loans, investments, assets, liabilities, budgets, and net worth — with no dependency on cloud services or third-party bank integrations at MVP stage. All data is stored locally on-device in an SQLite database, ensuring privacy, offline reliability, and instant performance.

## 2. Problem Statement

Individuals track money across many disconnected surfaces — bank apps, UPI apps, wallets, credit cards, cash, and spreadsheets — with no unified view of true financial position. Existing budgeting apps are either cloud-dependent (privacy risk, requires internet, subscription-gated) or too simplistic (income/expense only, no loans, no investments, no net worth). This product solves that by combining full-scope financial tracking with a local, private, always-available data store.

## 3. Product Vision

A single Flutter app, running fully offline, that acts as the user's personal financial ledger — accurate to the rupee (or any currency), auditable, and comprehensive enough to replace both a banking app and a spreadsheet, while remaining simple enough for daily use.

## 4. Goals & Objectives

1. Track every personal financial transaction across all account types.
2. Maintain mathematically accurate, always-current balances per account.
3. Cleanly separate income, expense, transfer, investment, loan, and adjustment logic so reports are never distorted.
4. Support the full set of Indian and general personal financial instruments (cash, bank, UPI, wallets, FD/RD, credit cards, loans).
5. Provide budgeting, financial goals, and net-worth tracking.
6. Support recurring/scheduled transactions with reliable auto-generation.
7. Deliver rich reports/dashboards using local computation only.
8. Guarantee data privacy: all data stays on-device unless the user explicitly exports it.
9. Provide reconciliation tooling to catch missing/duplicate transactions.
10. Ship a single, comprehensive, production-grade build rather than a bare-bones MVP.

## 5. Target Users

- Individuals managing multiple accounts (bank, cash, UPI, credit cards) who want one unified ledger.
- Users who want full control/privacy over financial data (no cloud sync required).
- Users with loans, investments, or lending/borrowing activity that simple expense trackers don't model.
- Freelancers/small earners with irregular income who need cash-flow visibility.

## 6. User Personas

**Persona A — "The Multi-Account Juggler"**
Has a salary account, a savings account, 2 UPI apps, 1 credit card, and cash. Wants one dashboard showing total balance and where money actually goes each month.

**Persona B — "The Debt & Lending Tracker"**
Has an active home loan, a personal loan, and has lent money to family/friends. Needs clear tracking of principal vs. interest, and receivables from others.

**Persona C — "The Net-Worth Watcher"**
Actively invests (FDs, mutual funds) and wants to see assets minus liabilities trend over time, plus budget discipline.

## 7. Functional Requirements — Feature Modules

### 7.1 Account Management
Supported account types (minimum set): Cash, Bank Account, Savings Account, Current Account, Salary Account, Credit Card, Debit Card, UPI, Digital Wallet, Fixed Deposit, Recurring Deposit, Investment Account, Loan Account (Personal/Home/Vehicle), Money Lent Account, Money Borrowed Account, Other.

Each account stores: name, type, institution/provider, masked account reference, opening balance, current balance, available balance, currency, status (active/closed/frozen), opening date, notes, tags, credit limit (if applicable), interest rate (if applicable), and account-specific settings (e.g., billing cycle for credit cards).

### 7.2 Transaction Engine
A single flexible transaction table drives all money movement, categorized as:

- **Income:** Salary, Freelancing, Business income, Interest, Dividend, Rental income, Cashback, Bonus, Commission, Gifts received, Refund received, Other income.
- **Expenses:** Food, Groceries, Rent, Utilities (Electricity/Water/Internet/Mobile), Transportation, Fuel, Education, Healthcare, Insurance, Shopping, Entertainment, Travel, Subscriptions, EMI, Taxes, Household, Personal, Gifts given, Donations, Other.
- **Transfers:** Account-to-account, cash deposit/withdrawal, bank transfer, UPI transfer, wallet transfer, credit-card payment. Transfers never count as income or expense.
- **Other types:** Refund, Reversal, Adjustment, Opening/Closing balance, Loan received/repayment/disbursement, Money lent/received back, Investment purchase/sale, Dividend received, Interest received/paid, Fees, Charges, Cashback, Discounts, Foreign-currency transactions.

Each transaction record includes: source account, destination account (if applicable), type, amount, date, category, subcategory, description, payee/payer, payment method, reference number, tags, notes, attachments, and status.

### 7.3 Financial / Accounting Logic (Business Rules)
- Income increases the relevant account balance; expense decreases it.
- Transfers decrease source and increase destination without touching income/expense totals.
- Credit-card purchases increase card liability and record the expense once.
- Credit-card payments reduce card liability and reduce bank/cash balance — never double-counted as an expense.
- Loan received increases cash/bank balance and increases loan liability.
- Loan repayment reduces loan liability and account balance; interest portion is recorded separately as an expense.
- Amount must be > 0; transfer source ≠ destination; reversals must exactly negate the original entry; account balances must remain mathematically consistent at all times.

### 7.4 Transaction Status
Pending, Completed, Failed, Cancelled, Reversed, Refunded, Scheduled — with a full audit trail per status change.

### 7.5 Recurring Transactions
User-defined recurring entries (salary, rent, utility bills, EMI, insurance, SIP, RD, allowance) with frequency (daily/weekly/monthly/quarterly/half-yearly/yearly/custom), start/end date, next execution date, and automatic generation via a local background scheduler — with safeguards against duplicate generation.

### 7.6 Budget Management
Monthly, annual, category-wise, account-wise, and custom budgets with spending limits, alerts, and a Budget → Actual → Remaining → % Used view per category and overall.

### 7.7 Dashboard
Single home screen showing: total balance, cash, bank balances, credit-card outstanding, total income/expenses, savings, investments, loans, receivables, payables, assets, liabilities, net worth, monthly cash flow, budget status, upcoming payments, recurring transactions, and recent activity — with daily/weekly/monthly/quarterly/yearly toggles, rendered with fl_chart.

### 7.8 Reports & Analytics
Income, expense (category-wise and account-wise), cash-flow, month-over-month and year-over-year comparison, savings, investment, loan, credit-card, budget, net-worth, asset, liability, receivable, payable, recurring-expense, and tax-related transaction reports — all chart-backed where useful.

### 7.9 Search & Filtering
Filter by date range, account, type, category/subcategory, amount range, payee/payer, payment method, status, tags, recurring flag, and income/expense/transfer classification; sortable by date, amount, account, category.

### 7.10 Reconciliation
Compare app balance vs. real-world account balance, mark transactions reconciled, surface missing/duplicate transactions, record reconciliation adjustments, and keep reconciliation history.

### 7.11 Import & Export
CSV/Excel import and export, PDF report export, bank/card statement import with a categorize-and-map step before final confirmation, and duplicate-transaction detection on import.

### 7.12 Attachments & Documents
Attach bills, receipts, invoices, statements, payment screenshots, loan documents, investment documents, and insurance documents to a transaction or account, stored as local file references.

### 7.13 Financial Goals
Goals such as emergency fund, vehicle, home purchase, vacation, education, investment target, and general savings target, tracked as Goal Amount → Current Amount → Remaining → Progress % → Target Date.

### 7.14 Net Worth
Net Worth = Total Assets − Total Liabilities, with historical tracking over time. Assets: cash, bank balances, investments, FDs, property, vehicles, other. Liabilities: credit-card outstanding, home/vehicle/personal loans, money borrowed, other.

### 7.15 Notifications & Alerts (Local)
Local (on-device) notifications for upcoming bills, EMI/credit-card due dates, budget overspending, low balance, recurring-transaction execution, loan due dates, goal milestones, and reconciliation differences.

### 7.16 Audit & History
Full change log for created/edited/deleted/restored transactions and account/budget/reconciliation changes, recording timestamp, action, previous value, new value, and device.

## 8. Non-Functional Requirements

- **Offline-first:** 100% of core functionality works with no network connection.
- **Privacy:** No data leaves the device unless the user explicitly triggers export/backup.
- **Performance:** Dashboard and reports must render from local SQLite queries in under ~300ms for typical data volumes (up to tens of thousands of transactions).
- **Reliability:** Local database writes must be transactional; no partial writes on crash.
- **Portability:** Same Flutter codebase targets mobile (Android/iOS) and desktop (Windows/macOS/Linux) with responsive layouts.
- **Data integrity:** Automated local backup file (encrypted) with restore capability.

## 9. Recommended Tech Stack (Flutter + Local Database)

- **Framework:** Flutter (single codebase for mobile, tablet, and desktop).
- **State management / architecture:** Riverpod, MVVM pattern (View → ViewModel/Notifier → Repository → Local Data Source).
- **Local database:** SQLite via `drift` (recommended for type-safe queries, migrations, and reactive streams) or `sqflite` with a repository layer if a lighter dependency is preferred.
- **Charts/visualization:** `fl_chart` for dashboard and report visualizations.
- **Local file storage:** `path_provider` + local app-sandbox directories for attachments/documents.
- **Local notifications:** `flutter_local_notifications` for bill/EMI/budget alerts.
- **Background scheduling:** `workmanager` (Android) / platform-appropriate schedulers for recurring-transaction generation, with an in-app "catch-up on launch" check as a fallback.
- **Import/export:** `csv` and `excel`/`syncfusion_flutter_xlsio` packages for CSV/Excel; `pdf`/`printing` packages for PDF report export.
- **Security:** Local biometric/PIN lock via `local_auth`; database-level encryption via `sqlcipher_flutter_libs` (SQLCipher) for at-rest encryption; encrypted local backup files.
- **Backup/restore:** Export encrypted `.db`/archive to user-chosen local storage or user-controlled cloud folder (e.g., a folder the user picks via file picker) — cloud sync is opt-in only, never default.

## 10. Database Schema (Core Entities)

- **users** — single local profile: id, name, currency, PIN/biometric settings.
- **accounts** — id, name, type, institution, masked_reference, opening_balance, current_balance, currency, status, credit_limit, interest_rate, opened_at, notes.
- **account_types** — lookup table for the account type list in §7.1.
- **transactions** — id, source_account_id, destination_account_id (nullable), type, category_id, subcategory_id, amount, date, description, payee_payer, payment_method, reference_number, status, is_recurring_instance_of (nullable FK), created_at, updated_at.
- **categories / subcategories** — id, name, parent_type (income/expense/transfer/other), parent_category_id.
- **payees_payers** — id, name, default_category_id (optional), notes.
- **budgets** — id, scope (category/account/overall), period_type, amount_limit, start_date, end_date.
- **recurring_transactions** — id, template transaction fields, frequency, start_date, end_date, next_execution_date, is_active.
- **loans** — id, account_id, principal, interest_rate, term, outstanding_balance, start_date.
- **investments** — id, account_id, instrument_type, purchase_value, current_value, purchase_date.
- **assets / liabilities** — id, name, type, current_value, linked_account_id (nullable).
- **financial_goals** — id, name, target_amount, current_amount, target_date, linked_account_id (nullable).
- **attachments** — id, transaction_id/account_id (nullable FKs), file_path, type, uploaded_at.
- **tags / transaction_tags** — many-to-many tagging.
- **reconciliation_records** — id, account_id, statement_balance, app_balance, reconciled_at, notes.
- **audit_logs** — id, entity_type, entity_id, action, previous_value_json, new_value_json, timestamp.
- **settings** — key-value local app settings.

Relationships: an `account` has many `transactions` (as source or destination); a `transaction` belongs to one `category`/`subcategory` and optionally one `payee_payer`; `recurring_transactions` generate `transactions`; `loans`/`investments`/`assets`/`liabilities` optionally link back to an `account`; `attachments` and `tags` attach to either transactions or accounts; every mutating action writes an `audit_logs` row.

## 11. UI/UX Requirements

Primary navigation: Dashboard, Accounts, Transactions, Income, Expenses, Transfers, Budgets, Recurring, Loans, Investments, Assets, Liabilities, Goals, Reports, Reconciliation, Documents, Settings.

- Responsive layout: bottom-nav on mobile, side-nav/rail on tablet and desktop.
- Fast "Add Transaction" entry point accessible from anywhere (FAB or shortcut).
- Consistent design system: clear income (green) vs. expense (red) vs. transfer (neutral) color coding throughout.
- Empty states and onboarding for first account/first transaction.

## 12. Security Requirements

- App-level PIN and biometric lock (`local_auth`).
- SQLite database encrypted at rest (SQLCipher).
- Encrypted local backup/export files.
- No network calls required for core functionality; any future cloud/bank sync must be explicitly opt-in with its own consent screen.
- Session timeout/auto-lock after inactivity.

## 13. Validation & Error Handling

- Reject zero/negative amounts and identical source/destination transfers at the form level.
- Prevent duplicate recurring-transaction generation via a last-run timestamp check on app launch.
- Surface reconciliation mismatches as actionable warnings, not silent failures.
- All deletes are soft-deletes with audit trail and a "restore" option.

## 14. Edge Cases

- Multi-currency accounts and currency conversion display.
- Backdated or future-dated transactions affecting already-reconciled periods.
- Editing a transaction that is part of a recurring series (edit this instance vs. edit series).
- Partial loan prepayments changing amortization schedule.
- Reversing a transfer that already spawned downstream transactions.

## 15. Development Priorities — MVP vs Phase 2 vs Phase 3

**MVP (Phase 1):** Accounts (all core types), full transaction engine with income/expense/transfer logic, categories, dashboard, basic reports, recurring transactions, local PIN lock, CSV export.

**Phase 2:** Budgets, financial goals, net-worth tracking, loans module, reconciliation, attachments/documents, CSV/Excel/statement import with duplicate detection, local notifications.

**Phase 3:** Investments module, PDF report export, database encryption (SQLCipher), encrypted backup/restore, multi-currency, advanced analytics (trend forecasting, anomaly detection).

## 16. Future Enhancements

Bank statement auto-sync, UPI/Open Banking integration, AI-powered spending insights and smart categorization, receipt OCR, subscription and anomaly detection, tax planning tools, and optional multi-user/family shared finances (opt-in, still local-first where possible).

## 17. Testing Requirements

- Unit tests for all balance-calculation and transaction-logic functions (income/expense/transfer/loan/credit-card rules in §7.3).
- Widget tests for transaction entry, budget, and dashboard screens.
- Integration tests covering: add income → balance updates; transfer → both accounts update, no income/expense impact; credit-card purchase + payment → no double expense; recurring transaction → correct auto-generation with no duplicates; reconciliation flow.
- Migration tests for schema changes on the local SQLite database.

## 18. Acceptance Criteria

The system is complete when: all account types can be created; all transaction types can be recorded; balances always calculate correctly; transfers never distort income/expense reports; credit-card and loan logic behave per §7.3; recurring transactions run reliably without duplication; budgets and net worth calculate correctly; reports reconcile against raw transaction data; data can be imported/exported and backed up/restored locally; and the full transaction history remains searchable and auditable.

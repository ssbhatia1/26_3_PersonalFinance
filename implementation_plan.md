# Implementation Plan: Comprehensive Breakdown Tab (Expenses, Income & Account Flows)

This plan expands the Breakdown tab in the Reports module to include **Income Categorical Breakdown** and **Account Inflow/Outflow Breakdown**, resolving the missing analytics requested by the user.

---

## User Review Required

> [!IMPORTANT]
> - Tab 2 (currently labeled "Spending Breakdown") will become **"Breakdown (Expense, Income & Accounts)"** with a top segmented toggle:
>   1. **Expense Breakdown**: Visualizes expenses across categories (Donut chart, comparison bars, ranked spending list).
>   2. **Income Breakdown**: Visualizes income across categories and sources (Donut chart, comparison bars, ranked income list).
>   3. **Account Flow Breakdown**: Visualizes total inflows (income + transfers in), outflows (expenses + transfers out), and net balance changes per account with progress indicators and current balances.
> - All analytics are derived **100% dynamically from actual stored SQLite database transactions**.

---

## Proposed Changes

### 1. Data Layer & Repositories

#### [MODIFY] [transaction_repository.dart](file:///c:/Users/ssbha/Desktop/CI_Projects/26_3_PersonalFinance/lib/data/repositories/transaction_repository.dart)
- **`getCategoryIncomeSummary(start, end, {String? accountId})`**: Support optional `accountId` filter matching `getCategorySpendingSummary`.
- **`getAccountFlowSummary(start, end)`** [NEW]:
  - Aggregates per account:
    - `total_inflow`: Income deposited into account + Transfers received (where destination is account).
    - `total_outflow`: Expenses paid from account + Transfers sent (where source is account).
    - `net_flow`: `total_inflow - total_outflow`.
    - `current_balance`: Current balance of the account.
    - `tx_count`: Number of transactions involving the account in the period.

---

### 2. UI Layer (`lib/ui/reports/`)

#### [MODIFY] [reports_screen.dart](file:///c:/Users/ssbha/Desktop/CI_Projects/26_3_PersonalFinance/lib/ui/reports/reports_screen.dart)
- Update Tab 2 header: `Tab(icon: Icon(Icons.pie_chart_rounded), text: 'Breakdown & Account Flows')`.
- In `_loadReportData`: Fetch `categoryIncome` via `txRepo.getCategoryIncomeSummary(...)` and `accountFlows` via `txRepo.getAccountFlowSummary(...)`.
- Add Segmented Control in Tab 2:
  - `[Expenses | Income | Accounts]`
- **Income View**:
  - `CategoryDonutChart` for Income categories.
  - `CategoryComparisonBarChart` for Income categories.
  - Ranked Category Inflow list.
- **Account Flow View**:
  - Account flow summary cards with Inflow (+), Outflow (-), Net Flow (±), and Current Balance.
  - Visual comparison bars showing inflow vs outflow per account.
  - Empty state when no account transactions exist in the period.

---

## Verification Plan

### Automated Tests
1. Run existing test suite to ensure zero regressions:
   ```powershell
   flutter test
   ```
2. Add dedicated test cases in `test/reports_breakdown_test.dart`:
   - Verify `getCategoryIncomeSummary` returns accurate category income breakdown from real transactions.
   - Verify `getAccountFlowSummary` calculates accurate account-wise inflows, outflows, transfers in/out, and net flow.
   - Verify widget renders Expenses, Income, and Accounts segmented views properly.
3. Run linter:
   ```powershell
   flutter analyze
   ```

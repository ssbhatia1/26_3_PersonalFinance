import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/models/investment.dart';
import 'package:personal_finance/data/models/loan.dart';
import 'package:personal_finance/data/models/loan_repayment.dart';
import 'package:personal_finance/data/models/recurring_transaction.dart';
import 'package:personal_finance/data/models/report.dart';
import 'package:personal_finance/data/models/transaction.dart';

void main() {
  group('Report Models (report.dart)', () {
    test('CashFlowReport computes netSavings, savingsRate, and serializes correctly', () {
      final start = DateTime(2026, 3, 1);
      final end = DateTime(2026, 3, 31);
      final report = CashFlowReport(
        startDate: start,
        endDate: end,
        totalIncome: 100000.0,
        totalExpense: 60000.0,
      );

      expect(report.netSavings, 40000.0);
      expect(report.savingsRate, 40.0);
      expect(report.isPositive, isTrue);
      expect(report.isDeficit, isFalse);

      final map = report.toMap();
      final reconstituted = CashFlowReport.fromMap(map);
      expect(reconstituted, equals(report));
    });

    test('RunwayMetrics computes burn rates, days, months, and health status', () {
      final runway = RunwayMetrics.compute(
        liquidAssets: 90000.0,
        totalInflow: 50000.0,
        totalOutflow: 30000.0,
        daysInPeriod: 30,
      );

      expect(runway.avgDailyOutflow, 1000.0);
      expect(runway.avgWeeklyOutflow, 7000.0);
      expect(runway.runwayDays, 90);
      expect(runway.isInfiniteRunway, isFalse);
      expect(runway.healthStatus, 'healthy');

      // Test zero outflow / infinite runway
      final infiniteRunway = RunwayMetrics.compute(
        liquidAssets: 50000.0,
        totalInflow: 20000.0,
        totalOutflow: 0.0,
        daysInPeriod: 30,
      );
      expect(infiniteRunway.isInfiniteRunway, isTrue);
      expect(infiniteRunway.healthStatus, 'infinite');
    });

    test('FinancialReport aggregates sub-reports and exports clean CSV', () {
      final start = DateTime(2026, 3, 1);
      final end = DateTime(2026, 3, 31);
      final cashFlow = CashFlowReport(
        startDate: start,
        endDate: end,
        totalIncome: 80000.0,
        totalExpense: 40000.0,
      );
      final runway = RunwayMetrics.compute(
        liquidAssets: 120000.0,
        totalInflow: 80000.0,
        totalOutflow: 40000.0,
        daysInPeriod: 30,
      );
      final report = FinancialReport(
        id: 'rep_1',
        title: 'March 2026 Statement',
        period: 'this_month',
        startDate: start,
        endDate: end,
        generatedAt: DateTime(2026, 3, 31, 23, 59),
        cashFlow: cashFlow,
        runway: runway,
        categorySpendings: const [
          CategorySpendingReportItem(
            categoryId: 'cat_groceries',
            categoryName: 'Groceries',
            amount: 15000.0,
            percentage: 37.5,
          ),
          CategorySpendingReportItem(
            categoryId: 'cat_rent',
            categoryName: 'Rent',
            amount: 25000.0,
            percentage: 62.5,
          ),
        ],
        totalNetWorth: 500000.0,
      );

      final csv = report.toCsv();
      expect(csv.contains('Total Income,80000.0'), isTrue);
      expect(csv.contains('Net Savings,40000.0'), isTrue);
      expect(csv.contains('Groceries,15000.0,37.50%'), isTrue);

      final map = report.toMap();
      final fromMapReport = FinancialReport.fromMap(map);
      expect(fromMapReport.title, 'March 2026 Statement');
      expect(fromMapReport.categorySpendings.length, 2);
    });
  });

  group('Loan & LoanRepayment Models (loan.dart & loan_repayment.dart)', () {
    test('Loan handles boolean type-safety (int and bool) and calculates EMI', () {
      final now = DateTime(2026, 1, 1);
      final mapWithInt = {
        'id': 'loan_1',
        'account_id': 'acc_hdfc',
        'borrower_lender_name': 'HDFC Bank',
        'loan_type': 'borrowed',
        'principal': 120000.0,
        'interest_rate': 12.0,
        'is_flexible_interest': 1,
        'term_months': 12,
        'outstanding_balance': 100000.0,
        'start_date': now.toIso8601String(),
        'emi_amount': 0.0,
        'status': 'active',
        'account_name': 'HDFC Salary Account',
      };

      final loanFromInt = Loan.fromMap(mapWithInt);
      expect(loanFromInt.isFlexibleInterest, isTrue);
      expect(loanFromInt.accountName, 'HDFC Salary Account');
      expect(loanFromInt.isActive, isTrue);
      expect(loanFromInt.isClosed, isFalse);

      // Verify EMI calculation works when emiAmount is 0
      expect(loanFromInt.calculatedEmi, greaterThan(10000.0));
      expect(loanFromInt.maturityDate.year, 2027);
      expect(loanFromInt.maturityDate.month, 1);

      // Verify JSON with boolean does not crash
      final mapWithBool = Map<String, dynamic>.from(mapWithInt);
      mapWithBool['is_flexible_interest'] = true;
      final loanFromBool = Loan.fromMap(mapWithBool);
      expect(loanFromBool.isFlexibleInterest, isTrue);
    });

    test('LoanRepayment serialization and equality work as expected', () {
      final now = DateTime.now();
      final repayment = LoanRepayment(
        id: 'lr_1',
        loanId: 'loan_1',
        paymentAmount: 10661.0,
        principalAmount: 9661.0,
        interestAmount: 1000.0,
        paymentDate: now,
        accountId: 'acc_hdfc',
        accountName: 'HDFC Salary Account',
        createdAt: now,
      );

      final map = repayment.toMap();
      map['account_name'] = 'HDFC Salary Account';
      final reconstituted = LoanRepayment.fromMap(map);
      expect(reconstituted.id, repayment.id);
      expect(reconstituted.paymentAmount, 10661.0);
      expect(reconstituted.accountName, 'HDFC Salary Account');
    });
  });

  group('Investment Model (investment.dart)', () {
    test('InvestmentType.fromString supports case-insensitive and display names', () {
      expect(InvestmentType.fromString('fd'), InvestmentType.fd);
      expect(InvestmentType.fromString('Fixed Deposit'), InvestmentType.fd);
      expect(InvestmentType.fromString('MUTUAL_FUND'), InvestmentType.mutualFund);
      expect(InvestmentType.fromString('Mutual Funds'), InvestmentType.mutualFund);
      expect(InvestmentType.fromString('stock'), InvestmentType.stock);
      expect(InvestmentType.fromString('Stocks'), InvestmentType.stock);
      expect(InvestmentType.fromString('unknown'), InvestmentType.other);
    });

    test('Investment handles accountName joined field, safe boolean parsing, and CAGR', () {
      final start = DateTime.now().subtract(const Duration(days: 365));
      final now = DateTime.now();
      final inv = Investment(
        id: 'inv_1',
        name: 'Nifty 50 Index Fund',
        type: InvestmentType.mutualFund,
        accountId: 'acc_zerodha',
        accountName: 'Zerodha Trading',
        investedAmount: 100000.0,
        currentValue: 120000.0,
        startDate: start,
        createdAt: start,
        updatedAt: now,
      );

      expect(inv.profitLoss, 20000.0);
      expect(inv.profitLossPercentage, 20.0);
      expect(inv.accountName, 'Zerodha Trading');
      expect(inv.holdingPeriodDays, greaterThanOrEqualTo(364));
      expect(inv.cagrPercentage, closeTo(20.0, 1.0));

      final map = inv.toMap();
      map['is_deleted'] = false; // test boolean in map
      map['account_name'] = 'Zerodha Trading';

      final reconstituted = Investment.fromMap(map);
      expect(reconstituted.accountName, 'Zerodha Trading');
      expect(reconstituted.isDeleted, isFalse);
      expect(reconstituted.name, 'Nifty 50 Index Fund');
    });
  });

  group('RecurringTransaction & Transaction Models', () {
    test('RecurringTransaction safe date roll prevents month overflow (Jan 31 -> Feb 28)', () {
      final jan31 = DateTime(2026, 1, 31);
      final recurringMonthly = RecurringTransaction(
        id: 'rec_month_end',
        title: 'Salary / Rent End of Month',
        sourceAccountId: 'acc_1',
        type: 'income',
        amount: 50000.0,
        frequency: 'monthly',
        startDate: jan31,
        nextExecutionDate: jan31,
      );

      // When advancing by 1 month from Jan 31 in 2026 (non-leap year), it should clamp to Feb 28, NOT March 3!
      final nextDate = recurringMonthly.calculateNextDate(jan31);
      expect(nextDate.year, 2026);
      expect(nextDate.month, 2);
      expect(nextDate.day, 28);

      // When advancing quarterly from Jan 31, it should clamp to April 30, NOT May 1!
      final quarterly = recurringMonthly.copyWith(frequency: 'quarterly');
      final qNextDate = quarterly.calculateNextDate(jan31);
      expect(qNextDate.year, 2026);
      expect(qNextDate.month, 4);
      expect(qNextDate.day, 30);

      // Custom 2 months from Jan 31 should be March 31
      final custom2Months = recurringMonthly.copyWith(
        frequency: 'custom',
        intervalCount: 2,
        intervalUnit: 'months',
      );
      final customNext = custom2Months.calculateNextDate(jan31);
      expect(customNext.year, 2026);
      expect(customNext.month, 3);
      expect(customNext.day, 31);
    });

    test('RecurringTransaction handles boolean type-safety and lifecycle helpers', () {
      final now = DateTime.now();
      final map = {
        'id': 'rec_sub',
        'title': 'Cloud Storage',
        'source_account_id': 'acc_1',
        'type': 'expense',
        'amount': 210.0,
        'frequency': 'monthly',
        'start_date': now.toIso8601String(),
        'next_execution_date': now.add(const Duration(days: 2)).toIso8601String(),
        'is_active': true, // boolean instead of 1
        'is_flexible_amount': false, // boolean instead of 0
      };

      final rec = RecurringTransaction.fromMap(map);
      expect(rec.isActive, isTrue);
      expect(rec.isFlexibleAmount, isFalse);
      expect(rec.isDueSoon(3), isTrue);
      expect(rec.isOverdue, isFalse);
    });

    test('TransactionModel handles boolean type-safety, status helpers, and equality', () {
      final now = DateTime.now();
      final map = {
        'id': 'tx_123',
        'source_account_id': 'acc_1',
        'type': 'expense',
        'amount': 450.0,
        'date': now.toIso8601String(),
        'status': 'completed',
        'is_reconciled': true, // boolean in JSON
        'is_deleted': false, // boolean in JSON
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'source_account_name': 'Main Checking',
      };

      final tx = TransactionModel.fromMap(map);
      expect(tx.isReconciled, isTrue);
      expect(tx.isDeleted, isFalse);
      expect(tx.isCompleted, isTrue);
      expect(tx.isPending, isFalse);
      expect(tx.sourceAccountName, 'Main Checking');

      // Verify equality
      final sameTx = TransactionModel.fromMap(map);
      expect(tx, equals(sameTx));
    });
  });
}
